import ConciergeCore
import Foundation
import GRDB

/// Reads the whole database for a backup and replaces it on restore.
public struct BackupStore: Sendable {
    public let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    /// Everything, read in one transaction so the backup is consistent.
    public func exportPayload(appVersion: String, at now: Date = Date()) throws -> BackupPayload {
        let settings = database.loadSettings()
        return try database.writer.read { db in
            BackupPayload(
                createdAt: now,
                appVersion: appVersion,
                settings: settings,
                alarms: try Alarm.order(Column("createdAt")).fetchAll(db),
                wakeEvents: try WakeEvent.order(Column("scheduledAt")).fetchAll(db),
                recommendations: try Recommendation.order(Column("createdAt")).fetchAll(db)
            )
        }
    }

    /// Replaces all data with a backup in one transaction: if anything fails, nothing changes.
    /// Settings are restored too, except onboarding (stays completed) and the backup
    /// bookkeeping of this iPhone (auto-backup folder and dates stay as they are).
    public func replaceAll(with payload: BackupPayload) throws {
        guard payload.integrityIssues.isEmpty else { throw BackupError.inconsistent }
        let alarmIDs = Set(payload.alarms.map(\.id))
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM wakeEvent")
            try db.execute(sql: "DELETE FROM recommendation")
            try db.execute(sql: "DELETE FROM alarm")
            for var alarm in payload.alarms {
                // A hand-edited file may hold days outside 1...7; keep only real weekdays.
                alarm.repeatDays = alarm.repeatDays.filter { (1...7).contains($0) }
                try alarm.insert(db)
            }
            for var event in payload.wakeEvents {
                if let id = event.alarmID, !alarmIDs.contains(id) { event.alarmID = nil }
                try event.insert(db)
            }
            for var recommendation in payload.recommendations {
                if let id = recommendation.alarmID, !alarmIDs.contains(id) { recommendation.alarmID = nil }
                try recommendation.insert(db)
            }
        }
        let current = database.loadSettings()
        var settings = payload.settings
        settings.hasCompletedOnboarding = true
        settings.autoBackupEnabled = current.autoBackupEnabled
        settings.lastAutoBackupAt = current.lastAutoBackupAt
        settings.lastBackupAt = current.lastBackupAt
        try database.saveSettings(settings)
    }
}
