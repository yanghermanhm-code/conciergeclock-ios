import ConciergeCore
import ConciergeData
import Foundation
import Observation

/// Observable wrapper around `AppSettings`. Every change is written to the database.
@MainActor
@Observable
final class SettingsStore {
    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persist()
        }
    }

    private(set) var lastError: String?

    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
        self.settings = database.loadSettings()
    }

    /// Re-reads the settings from the database (after a backup is restored).
    func reload() {
        settings = database.loadSettings()
    }

    private func persist() {
        do {
            try database.saveSettings(settings)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
