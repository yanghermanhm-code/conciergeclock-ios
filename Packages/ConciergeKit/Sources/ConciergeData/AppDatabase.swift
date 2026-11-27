import Foundation
import GRDB
import ConciergeCore

/// The app's single on-device SQLite database.
///
/// It lives in Application Support (never in `Caches/`), so iOS never purges it during
/// low-storage cleanup. Nested values (repeat days, recommendation parameters) are stored as JSON
/// columns. Settings and the auto-backup folder live in the `keyValue` table.
public final class AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Migrations.migrator.migrate(writer)
    }

    // MARK: Factories

    /// Opens (creating if needed) the on-disk database used by the app.
    public static func openShared() throws -> AppDatabase {
        try open(at: try DatabaseLocation.resolveURL())
    }

    /// Opens (creating if needed) a database file at a specific location.
    public static func open(at url: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        var config = Configuration()
        config.foreignKeysEnabled = true
        #if DEBUG
        config.publicStatementArguments = true
        #endif
        let pool = try DatabasePool(path: url.path, configuration: config)
        return try AppDatabase(pool)
    }

    /// An empty in-memory database, for tests and SwiftUI previews.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    /// Path of the database file, or nil for in-memory databases.
    public var fileURL: URL? {
        let path = writer.path
        guard !path.isEmpty, path != ":memory:" else { return nil }
        return URL(fileURLWithPath: path)
    }

    // MARK: Key-value documents

    enum Key {
        static let settings = "settings"
        static let schemaVersion = "schemaVersion"
        static let autoBackupFolder = "autoBackupFolderBookmark"
    }

    func readDocument<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        let data = try writer.read { db in
            try Data.fetchOne(db, sql: "SELECT value FROM keyValue WHERE key = ?", arguments: [key])
        }
        guard let data else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func writeDocument<T: Encodable>(_ value: T, key: String) throws {
        let data = try JSONEncoder().encode(value)
        try writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO keyValue (key, value) VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                arguments: [key, data]
            )
        }
    }
}

// MARK: - Settings

public extension AppDatabase {
    /// Stored settings, or defaults if none were saved yet. A corrupt document never blocks
    /// launch: it falls back to defaults.
    func loadSettings() -> AppSettings {
        ((try? readDocument(AppSettings.self, key: Key.settings)) ?? nil) ?? .default
    }

    func saveSettings(_ settings: AppSettings) throws {
        try writeDocument(settings, key: Key.settings)
    }

    /// The security-scoped bookmark of the folder automatic backups are saved to (nil = none).
    /// Kept out of the settings document so it never travels inside a backup.
    func loadAutoBackupBookmark() -> Data? {
        (try? readDocument(Data.self, key: Key.autoBackupFolder)) ?? nil
    }

    func saveAutoBackupBookmark(_ bookmark: Data?) throws {
        if let bookmark {
            try writeDocument(bookmark, key: Key.autoBackupFolder)
        } else {
            try writer.write { db in
                try db.execute(sql: "DELETE FROM keyValue WHERE key = ?", arguments: [Key.autoBackupFolder])
            }
        }
    }

    /// The schema version recorded by the migrations.
    func storedSchemaVersion() throws -> Int? {
        try readDocument(Int.self, key: Key.schemaVersion)
    }
}
