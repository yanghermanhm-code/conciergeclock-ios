import ActivityKit
import AlarmKit
import ConciergeCore
import ConciergeData
import Foundation
import GGSBrand
import Observation
import SwiftUI
import WidgetKit

/// Hands Concierge Clock's alarms to AlarmKit, iOS's own alarm system, so they ring through
/// silent mode and Focus, on the Lock Screen and in the Dynamic Island, even when the app is
/// closed. It keeps the next two rings of every alarm scheduled (`AlarmPlanner`), writes the wake
/// log when a ring is stopped, and updates the widgets.
@MainActor
@Observable
final class AlarmScheduler {
    enum Authorization: Equatable {
        case notDetermined, authorized, denied
    }

    private(set) var authorization: Authorization = .notDetermined
    /// The last scheduling error, shown on the Alarms tab.
    private(set) var lastError: String?
    /// The next planned rings (for the Alarms tab and the Concierge tab).
    private(set) var upcoming: [PlannedRing] = []

    private let database: AppDatabase
    private let settings: SettingsStore
    private let calendars: CalendarService
    private var occurrences: OccurrenceStore { OccurrenceStore(database: database) }
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    /// Rings seen ringing or snoozing while the app was running.
    @ObservationIgnored private var ringing: Set<UUID> = []
    @ObservationIgnored private var reconcileTask: Task<Void, Never>?

    init(database: AppDatabase, settings: SettingsStore, calendars: CalendarService) {
        self.database = database
        self.settings = settings
        self.calendars = calendars
        refreshAuthorization()
    }

    private var manager: AlarmManager { AlarmManager.shared }

    // MARK: Permission

    func refreshAuthorization() {
        authorization = Self.map(manager.authorizationState)
    }

    /// Asks for permission to schedule alarms (once; afterwards only iOS Settings can change it).
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            authorization = Self.map(try await Self.requestAlarmKitAuthorization())
        } catch {
            authorization = .denied
        }
        if authorization == .authorized { await reconcile() }
        return authorization == .authorized
    }

    private static func map(_ state: AlarmManager.AuthorizationState) -> Authorization {
        switch state {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .denied: .denied
        @unknown default: .denied
        }
    }

    // MARK: Planning

    /// Re-plans soon, coalescing bursts of changes (typing a label, flipping toggles).
    func setNeedsReconcile() {
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.reconcile()
        }
    }

    /// Makes AlarmKit's schedule match the alarms: schedules missing rings, withdraws rings no
    /// longer wanted, logs rings that were never stopped, and refreshes the widgets.
    func reconcile(now: Date = Date()) async {
        refreshAuthorization()
        let current = settings.settings
        logMissedRings(now: now, rules: current.wakeScoreRules)
        let alarms = (try? AlarmStore(database: database).all()) ?? []
        let isDayOff = calendars.dayOffChecker(keywords: current.dayOffKeywords, excluding: Set(current.excludedCalendarIDs), from: now)
        let rings = AlarmPlanner.plan(alarms: alarms, after: now, isDayOff: isDayOff)
        upcoming = rings
        writeWidgetSnapshot(rings: rings, alarms: alarms, settings: current)
        guard authorization == .authorized else { return }

        let wanted = Set(rings.map(\.id))
        let scheduled = (try? manager.alarms) ?? []
        for alarm in scheduled where !wanted.contains(alarm.id) && alarm.state == .scheduled {
            try? manager.cancel(id: alarm.id)
            try? occurrences.setStatus(.cancelled, id: alarm.id.uuidString, at: now)
        }
        let present = Set(scheduled.map(\.id))
        var failure: String?
        for ring in rings where !present.contains(ring.id) {
            guard let alarm = alarms.first(where: { $0.id == ring.alarmID }) else { continue }
            do {
                try await schedule(ring, alarm: alarm, settings: current)
            } catch {
                failure = error.localizedDescription
            }
        }
        lastError = failure
    }

    private func schedule(_ ring: PlannedRing, alarm: ConciergeCore.Alarm, settings: AppSettings) async throws {
        let snoozeMinutes = settings.snoozeMinutes(for: alarm)
        let l10n = Localizer(language: AppLanguage.resolve(code: settings.languageCode))
        let title = alarm.label.nonBlank ?? l10n["alarm.defaultTitle"]
        let request = RingRequest(
            id: ring.id, fireDate: ring.fireDate, alarmID: alarm.id, label: alarm.label, title: title,
            stopText: l10n["alarm.stop"], snoozeText: l10n["alarm.snooze"], snoozingText: l10n("alarm.snoozing", title),
            snoozeSeconds: TimeInterval(snoozeMinutes * 60),
            soundFile: Self.soundFile(for: alarm)
        )
        try await Self.scheduleRing(request)
        try? occurrences.insertIfNew(AlarmOccurrence(
            id: ring.id.uuidString, alarmID: alarm.id, scheduledAt: ring.fireDate, snoozeMinutes: snoozeMinutes
        ))
    }

    /// Everything AlarmKit needs for one ring, as plain values, so the call to AlarmKit happens
    /// outside the main actor without sending main-actor state across (Swift 6 data-race safety).
    private struct RingRequest: Sendable {
        let id: UUID
        let fireDate: Date
        let alarmID: String
        let label: String
        let title: String
        let stopText: String
        let snoozeText: String
        let snoozingText: String
        let snoozeSeconds: TimeInterval
        /// A file in Library/Sounds/, or nil for the iPhone's default alarm sound.
        let soundFile: String?
    }

    /// The alarm's chosen sound as a rendered file name (rendered now if missing), or nil for
    /// the iPhone default.
    private static func soundFile(for alarm: ConciergeCore.Alarm) -> String? {
        let sound = AlarmSound.resolve(alarm.soundID)
        guard sound.isSynthesised else { return nil }
        if SoundLibrary.fileURL(for: sound) == nil { SoundLibrary.renderMissing() }
        return SoundLibrary.fileURL(for: sound) == nil ? nil : sound.fileName
    }

    nonisolated private static func requestAlarmKitAuthorization() async throws -> AlarmManager.AuthorizationState {
        try await AlarmManager.shared.requestAuthorization()
    }

    nonisolated private static func scheduleRing(_ request: RingRequest) async throws {
        let snoozeButton = AlarmButton(text: LocalizedStringResource(stringLiteral: request.snoozeText), textColor: .white, systemImageName: "zzz")
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            // From iOS 26.1 the system draws the Stop button itself.
            alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: request.title),
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .countdown
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: request.title),
                stopButton: AlarmButton(text: LocalizedStringResource(stringLiteral: request.stopText), textColor: .white, systemImageName: "stop.fill"),
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .countdown
            )
        }
        let countdown = AlarmPresentation.Countdown(title: LocalizedStringResource(stringLiteral: request.snoozingText), pauseButton: nil)
        let attributes = AlarmAttributes<ConciergeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert, countdown: countdown),
            metadata: ConciergeAlarmMetadata(alarmID: request.alarmID, label: request.label),
            // A fixed colour: the attributes are encoded and drawn by the system.
            tintColor: Color(hex: 0x0B7470)
        )
        let configuration = AlarmManager.AlarmConfiguration<ConciergeAlarmMetadata>(
            // The snooze: after Snooze, the alarm rings again after the snooze length.
            countdownDuration: AlarmKit.Alarm.CountdownDuration(preAlert: nil, postAlert: request.snoozeSeconds),
            schedule: .fixed(request.fireDate),
            attributes: attributes,
            stopIntent: StopAlarmIntent(ringID: request.id.uuidString),
            secondaryIntent: SnoozeAlarmIntent(ringID: request.id.uuidString),
            sound: request.soundFile.map { AlertConfiguration.AlertSound.named($0) } ?? .default
        )
        _ = try await AlarmManager.shared.schedule(id: request.id, configuration: configuration)
    }

    // MARK: Stop, snooze, missed

    /// The Stop button (Lock Screen, Dynamic Island or the app): log the morning, plan ahead.
    func didStop(ringID: String, method: DismissMethod = .system, at now: Date = Date()) async {
        _ = try? occurrences.finish(id: ringID, stoppedAt: now, method: method, rules: settings.settings.wakeScoreRules, now: now)
        await reconcile(now: now)
    }

    /// The Snooze button.
    func didSnooze(ringID: String, at now: Date = Date()) {
        try? occurrences.addSnooze(id: ringID, at: now)
    }

    /// Rings more than three hours past due that were never stopped count as missed.
    private func logMissedRings(now: Date, rules: WakeScoreRules) {
        let active = Set(((try? manager.alarms) ?? []).filter { $0.state != .scheduled }.map(\.id.uuidString))
        for occurrence in (try? occurrences.scheduled()) ?? []
        where occurrence.scheduledAt.addingTimeInterval(AlarmOccurrence.missedAfter) < now && !active.contains(occurrence.id) {
            _ = try? occurrences.finish(id: occurrence.id, stoppedAt: nil, method: .missed, rules: rules, now: now)
        }
        try? occurrences.pruneFinished(before: now.addingTimeInterval(-60 * 24 * 3600))
    }

    /// While the app runs, follows AlarmKit's alarms: a ring that was ringing or snoozing and
    /// then disappears was stopped, even if the Stop button's report did not arrive.
    func startObservingSystemAlarms() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let updates = self?.manager.alarmUpdates else { return }
            for await alarms in updates {
                guard let self else { return }
                let active = Set(alarms.filter { $0.state == .alerting || $0.state == .countdown || $0.state == .paused }.map(\.id))
                let present = Set(alarms.map(\.id))
                let stopped = ringing.subtracting(present)
                ringing = ringing.union(active).intersection(present)
                for id in stopped {
                    await didStop(ringID: id.uuidString)
                }
            }
        }
    }

    // MARK: Widgets

    private func writeWidgetSnapshot(rings: [PlannedRing], alarms: [ConciergeCore.Alarm], settings: AppSettings) {
        guard let folder = SharedConfig.containerURL else { return }
        let next = rings.first
        let label = next.flatMap { ring in alarms.first { $0.id == ring.alarmID }?.label } ?? ""
        let snapshot = NextAlarmSnapshot(
            fireDate: next?.fireDate, label: label,
            enabledAlarmCount: alarms.filter(\.isEnabled).count, languageCode: settings.languageCode
        )
        // Only rewrite (and wake the widgets) when something they show changed.
        if let old = NextAlarmSnapshot.read(from: folder), old.fireDate == snapshot.fireDate, old.label == snapshot.label,
           old.enabledAlarmCount == snapshot.enabledAlarmCount, old.languageCode == snapshot.languageCode {
            return
        }
        try? snapshot.write(to: folder)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedConfig.nextAlarmWidgetKind)
    }
}
