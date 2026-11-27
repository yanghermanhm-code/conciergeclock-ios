import ConciergeCore
import Foundation
import GRDB

/// Versioned schema migrations. Rules (the same as PrepPilot and FocusFound):
/// - Never edit a migration that has shipped. Add a new one instead.
/// - When a migration changes the shape of exported data, bump `SchemaVersion.database`
///   (and `SchemaVersion.backup` if the backup layout changes) and teach `BackupMigrator` how to
///   upgrade older files.
///
/// Column names match the Swift property names of the ConciergeCore models; nested values
/// (repeat days, recommendation parameters) are stored as JSON text. docs/DATA_SCHEMA.md is the
/// contract, also for the future Android app.
enum Migrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1-schema") { db in
            try db.create(table: "keyValue") { t in
                t.primaryKey("key", .text)
                t.column("value", .blob).notNull()
            }

            try db.create(table: "alarm") { t in
                t.primaryKey("id", .text)
                t.column("schemaVersion", .integer).notNull()
                t.column("kind", .text).notNull()
                t.column("label", .text).notNull()
                t.column("hour", .integer).notNull()
                t.column("minute", .integer).notNull()
                t.column("repeatDays", .text).notNull()
                t.column("isEnabled", .boolean).notNull()
                t.column("snoozeMinutes", .integer)
                t.column("toneOverride", .text)
                t.column("accentOverride", .text)
                t.column("lengthOverride", .text)
                t.column("soundID", .text).notNull()
                t.column("rampUpSeconds", .integer).notNull()
                t.column("ambientSoundID", .text)
                t.column("skipDay", .text)
                t.column("skipOnDaysOff", .boolean).notNull()
                t.column("snoozeLimit", .integer)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            try db.create(table: "wakeEvent") { t in
                t.primaryKey("id", .text)
                t.column("schemaVersion", .integer).notNull()
                t.column("alarmID", .text).references("alarm", onDelete: .setNull)
                t.column("alarmLabel", .text).notNull()
                t.column("scheduledAt", .datetime).notNull()
                t.column("dismissedAt", .datetime)
                t.column("dismissMethod", .text).notNull()
                t.column("snoozeCount", .integer).notNull()
                t.column("snoozedMinutes", .integer).notNull()
                t.column("volume", .double)
                t.column("ambientSoundID", .text)
                t.column("wakeSoundID", .text)
                t.column("nightstandMode", .boolean).notNull()
                t.column("awakeCheck", .text).notNull()
                t.column("score", .integer).notNull()
                t.column("isSuccess", .boolean).notNull()
                t.column("dateKey", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "wakeEvent_on_dateKey", on: "wakeEvent", columns: ["dateKey"])
            try db.create(index: "wakeEvent_on_alarmID", on: "wakeEvent", columns: ["alarmID"])

            try db.create(table: "recommendation") { t in
                t.primaryKey("id", .text)
                t.column("schemaVersion", .integer).notNull()
                t.column("kind", .text).notNull()
                t.column("status", .text).notNull()
                t.column("alarmID", .text).references("alarm", onDelete: .setNull)
                t.column("parameters", .text).notNull()
                t.column("experimentStart", .text)
                t.column("experimentEnd", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("resolvedAt", .datetime)
            }
            try db.create(index: "recommendation_on_status", on: "recommendation", columns: ["status"])

            try db.execute(
                sql: "INSERT OR REPLACE INTO keyValue (key, value) VALUES (?, ?)",
                arguments: [AppDatabase.Key.schemaVersion, try JSONEncoder().encode(1)]
            )
        }

        return migrator
    }
}
