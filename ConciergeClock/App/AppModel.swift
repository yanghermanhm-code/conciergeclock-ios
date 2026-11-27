import ConciergeCore
import ConciergeData
import Foundation
import Observation
import UIKit

/// The app's four tabs. Settings opens from the gear in the top bar.
enum AppTab: Hashable {
    case alarms, concierge, sounds, trends
}

/// Composition root: owns the database, stores and services, and is injected into the
/// SwiftUI environment.
@MainActor
@Observable
final class AppModel {
    let database: AppDatabase
    let settings: SettingsStore
    let alarms: AlarmStore
    let wakeLog: WakeLogStore
    let backups: BackupService
    /// The iPhone's calendars and reminders (every account in iOS Settings).
    let calendars: CalendarService
    /// AlarmKit: real alarms, snooze, the wake log written by each ring, widgets.
    let scheduler: AlarmScheduler
    /// The offline AI model (Gemma): download, choice and engine. Shared with Greater Good
    /// Software's other apps.
    let models: ModelService

    var selectedTab: AppTab = .concierge
    /// A short error message shown as an alert.
    var alertMessage: String?
    /// All alarms, kept live from the database (earliest time of day first).
    private(set) var alarmList: [Alarm] = []
    /// How many mornings are in the wake log.
    private(set) var wakeEventCount = 0

    private var alarmsTask: Task<Void, Never>?
    private var wakeLogTask: Task<Void, Never>?

    init(database: AppDatabase) {
        self.database = database
        self.settings = SettingsStore(database: database)
        self.alarms = AlarmStore(database: database)
        self.wakeLog = WakeLogStore(database: database)
        self.backups = BackupService(database: database)
        self.models = ModelService(settings: settings)
        let calendars = CalendarService()
        self.calendars = calendars
        self.scheduler = AlarmScheduler(database: database, settings: settings, calendars: calendars)
    }

    /// The app's real database (Application Support, never purged by iOS).
    static func live() throws -> AppModel {
        AppModel(database: try AppDatabase.openShared())
    }

    /// An in-memory model for SwiftUI previews.
    static func preview() -> AppModel {
        // Previews only: an in-memory database cannot fail to open.
        AppModel(database: try! AppDatabase.inMemory())
    }

    /// Starts observing the database. Safe to call more than once.
    func start() {
        guard alarmsTask == nil else { return }
        scheduler.startObservingSystemAlarms()
        let alarmStore = alarms
        alarmsTask = Task { [weak self] in
            do {
                for try await list in alarmStore.observeAlarms() {
                    self?.alarmList = list
                    // Every change to an alarm re-plans what AlarmKit rings.
                    self?.scheduler.setNeedsReconcile()
                }
            } catch {
                self?.alertMessage = error.localizedDescription
            }
        }
        let log = wakeLog
        wakeLogTask = Task { [weak self] in
            do {
                for try await events in log.observeEvents() {
                    self?.wakeEventCount = events.count
                }
            } catch {
                self?.alertMessage = error.localizedDescription
            }
        }
    }

    /// The persona for on-demand briefings (Settings defaults).
    var persona: Persona {
        settings.settings.persona()
    }

    /// The next alarm to ring and when (days off and skips included), or nil.
    func nextAlarm(after now: Date = Date()) -> (alarm: Alarm, date: Date)? {
        if let ring = scheduler.upcoming.first(where: { $0.fireDate > now }),
           let alarm = alarmList.first(where: { $0.id == ring.alarmID }) {
            return (alarm, ring.fireDate)
        }
        return alarmList
            .compactMap { alarm in alarm.nextFireDate(after: now).map { (alarm: alarm, date: $0) } }
            .min { $0.date < $1.date }
    }

    // MARK: Alarms

    /// Saves an alarm. The first time, asks for permission to schedule alarms.
    func save(_ alarm: Alarm) {
        do {
            try alarms.save(alarm)
        } catch {
            alertMessage = error.localizedDescription
            return
        }
        Haptics.success(enabled: settings.settings.hapticsEnabled)
        if scheduler.authorization == .notDetermined {
            Task { await scheduler.requestAuthorization() }
        }
    }

    func delete(_ alarm: Alarm) {
        do {
            try alarms.delete(id: alarm.id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func setEnabled(_ enabled: Bool, for alarm: Alarm) {
        var changed = alarm
        changed.isEnabled = enabled
        if enabled { changed.skipDay = nil }
        save(changed)
    }

    /// Skips only the next ring (or undoes the skip).
    func toggleSkipNext(_ alarm: Alarm) {
        var changed = alarm
        if changed.skipDay != nil {
            changed.skipDay = nil
        } else if let next = nextRing(of: alarm) {
            changed.skipDay = DayKey(next)
        }
        save(changed)
    }

    /// The next ring of one alarm, with days off applied.
    func nextRing(of alarm: Alarm, after now: Date = Date()) -> Date? {
        scheduler.upcoming.first { $0.alarmID == alarm.id && $0.fireDate > now }?.fireDate ?? alarm.nextFireDate(after: now)
    }

    // MARK: Lifecycle

    func didBecomeActive() {
        models.refresh()
        calendars.refresh()
        scheduler.setNeedsReconcile()
        backups.autoBackupIfDue(settings: settings)
    }

    func didEnterBackground() {
        backups.autoBackupIfDue(settings: settings)
    }

    /// After a backup was restored: reload settings and go back to the first tab.
    func didRestoreBackup() {
        settings.reload()
        scheduler.setNeedsReconcile()
        selectedTab = .concierge
        Haptics.success(enabled: settings.settings.hapticsEnabled)
    }

    /// After the wake score rules changed in Settings: re-score the whole log.
    func rescoreWakeLog() {
        let rules = settings.settings.wakeScoreRules
        let log = wakeLog
        Task.detached(priority: .utility) {
            try? log.rescoreAll(rules: rules)
        }
    }

    func applyAppIcon(_ choice: AppIconChoice) {
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != choice.alternateIconName else { return }
        UIApplication.shared.setAlternateIconName(choice.alternateIconName) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in self?.alertMessage = error.localizedDescription }
        }
    }
}
