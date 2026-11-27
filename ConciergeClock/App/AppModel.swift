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
        let alarmStore = alarms
        alarmsTask = Task { [weak self] in
            do {
                for try await list in alarmStore.observeAlarms() {
                    self?.alarmList = list
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

    /// The next alarm to ring and when, or nil.
    func nextAlarm(after now: Date = Date()) -> (alarm: Alarm, date: Date)? {
        alarmList
            .compactMap { alarm in alarm.nextFireDate(after: now).map { (alarm: alarm, date: $0) } }
            .min { $0.date < $1.date }
    }

    // MARK: Lifecycle

    func didBecomeActive() {
        models.refresh()
        backups.autoBackupIfDue(settings: settings)
    }

    func didEnterBackground() {
        backups.autoBackupIfDue(settings: settings)
    }

    /// After a backup was restored: reload settings and go back to the first tab.
    func didRestoreBackup() {
        settings.reload()
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
