import ConciergeCore
import EventKit
import Foundation
import Observation
import SwiftUI

/// The iPhone's calendars and reminders, read on the iPhone with EventKit.
///
/// Concierge Clock never signs in to Google or Microsoft and never goes online for this: it reads
/// every account added in iOS Settings — iCloud, Google, Outlook.com, Exchange / Microsoft 365,
/// Yahoo, other CalDAV accounts, subscribed calendars and calendars on the iPhone. Adding an
/// account there makes it appear here automatically (Settings › Calendars & Reminders).
@MainActor
@Observable
final class CalendarService {
    enum Access: Equatable {
        case notDetermined, granted, denied
    }

    private(set) var eventAccess: Access = .notDetermined
    private(set) var reminderAccess: Access = .notDetermined
    /// Calendar accounts with their calendars, as in the iPhone's Calendar app.
    private(set) var calendarAccounts: [CalendarAccount] = []
    /// Reminder accounts with their lists.
    private(set) var reminderAccounts: [CalendarAccount] = []

    let store = EKEventStore()
    @ObservationIgnored private var observer: NSObjectProtocol?

    init() {
        refresh()
        // Accounts, calendars or events changed (also when an account is added in Settings).
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: Access

    /// Asks for full access to calendars (read; Concierge Clock never changes events).
    @discardableResult
    func requestCalendarAccess() async -> Bool {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        refresh()
        return granted
    }

    /// Asks for full access to reminders (read, and mark done when you ask by voice).
    @discardableResult
    func requestReminderAccess() async -> Bool {
        let granted = (try? await store.requestFullAccessToReminders()) ?? false
        refresh()
        return granted
    }

    /// Re-reads permissions and accounts.
    func refresh() {
        eventAccess = Self.access(for: .event)
        reminderAccess = Self.access(for: .reminder)
        if eventAccess == .granted {
            store.refreshSourcesIfNecessary()
        }
        calendarAccounts = eventAccess == .granted ? Self.accounts(store.calendars(for: .event)) : []
        reminderAccounts = reminderAccess == .granted ? Self.accounts(store.calendars(for: .reminder)) : []
    }

    private static func access(for type: EKEntityType) -> Access {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private static func accounts(_ calendars: [EKCalendar]) -> [CalendarAccount] {
        let grouped = Dictionary(grouping: calendars) { $0.source?.sourceIdentifier ?? "local" }
        return grouped.compactMap { _, calendars -> CalendarAccount? in
            guard let first = calendars.first else { return nil }
            let source = first.source
            return CalendarAccount(
                id: source?.sourceIdentifier ?? "local",
                kind: AccountKind(source: source),
                title: source?.title ?? "",
                calendars: calendars
                    .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, color: Color(cgColor: $0.cgColor)) }
                    .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            )
        }
        .sorted { ($0.kind.sortOrder, $0.title) < ($1.kind.sortOrder, $1.title) }
    }

    // MARK: Reading

    /// The calendars Concierge Clock reads (all, minus the ones switched off).
    func includedCalendars(excluding excluded: Set<String>) -> [EKCalendar] {
        guard eventAccess == .granted else { return [] }
        return store.calendars(for: .event).filter { !excluded.contains($0.calendarIdentifier) }
    }

    /// Events today (from now until midnight) in the included calendars, or nil without access.
    func eventCountToday(excluding excluded: Set<String>, now: Date = Date()) -> Int? {
        guard eventAccess == .granted else { return nil }
        let calendars = includedCalendars(excluding: excluded)
        guard !calendars.isEmpty, let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) else { return 0 }
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: calendars)
        return store.events(matching: predicate).count
    }

    /// A day-off test for the next `days` days, read once from the calendars (only all-day items
    /// are looked at). Without calendar access, no day counts as a day off.
    func dayOffChecker(keywords: [String], excluding excluded: Set<String>, from now: Date = Date(), days: Int = AlarmPlanner.horizonDays + 1) -> (DayKey) -> Bool {
        let calendars = includedCalendars(excluding: excluded)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        guard !calendars.isEmpty, let end = calendar.date(byAdding: .day, value: days, to: start) else { return { _ in false } }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        var itemsByDay: [DayKey: [AllDayItem]] = [:]
        for event in store.events(matching: predicate) where event.isAllDay {
            let item = AllDayItem(title: event.title ?? "", calendarTitle: event.calendar?.title ?? "")
            // An all-day event can span several days: count it on each.
            var day = calendar.startOfDay(for: max(event.startDate, start))
            let last = min(event.endDate, end)
            while day < last {
                itemsByDay[DayKey(day, calendar: calendar), default: []].append(item)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        let snapshot = itemsByDay.mapValues { DayOffRules.isDayOff($0, keywords: keywords) }
        return { snapshot[$0] ?? false }
    }
}

/// One account as the iPhone knows it.
struct CalendarAccount: Identifiable, Equatable {
    let id: String
    let kind: AccountKind
    /// "iCloud", "name@gmail.com", "Exchange", "Outlook"…
    let title: String
    let calendars: [CalendarInfo]
}

struct CalendarInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let color: Color
}

/// Where an account comes from, recognised from the iPhone's account type and name.
enum AccountKind: Equatable {
    case iCloud, google, outlook, yahoo, otherOnline, onMyPhone, subscribed, birthdays

    init(source: EKSource?) {
        guard let source else {
            self = .onMyPhone
            return
        }
        let title = source.title.lowercased()
        switch source.sourceType {
        case .exchange:
            self = .outlook
        case .mobileMe:
            self = .iCloud
        case .local:
            self = .onMyPhone
        case .subscribed:
            self = .subscribed
        case .birthdays:
            self = .birthdays
        case .calDAV:
            if title.contains("icloud") {
                self = .iCloud
            } else if title.contains("gmail") || title.contains("google") || title.contains("googlemail") {
                self = .google
            } else if title.contains("outlook") || title.contains("hotmail") || title.contains("live.") || title.contains("office365") {
                self = .outlook
            } else if title.contains("yahoo") {
                self = .yahoo
            } else {
                self = .otherOnline
            }
        @unknown default:
            self = .otherOnline
        }
    }

    var sortOrder: Int {
        switch self {
        case .iCloud: 0
        case .google: 1
        case .outlook: 2
        case .yahoo: 3
        case .otherOnline: 4
        case .onMyPhone: 5
        case .subscribed: 6
        case .birthdays: 7
        }
    }

    var systemImage: String {
        switch self {
        case .iCloud: "icloud"
        case .google: "g.circle"
        case .outlook: "envelope.circle"
        case .yahoo: "y.circle"
        case .otherOnline: "network"
        case .onMyPhone: "iphone"
        case .subscribed: "dot.radiowaves.up.forward"
        case .birthdays: "gift"
        }
    }
}
