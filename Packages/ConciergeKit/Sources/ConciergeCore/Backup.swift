import Foundation

/// A full backup: one readable JSON file (`.conciergeclock`) holding the settings, alarms, the
/// wake log and the Advisor's history. Written to a place the user chooses (Files, iCloud
/// Drive, AirDrop…); ConciergeClock never uploads it. Format: docs/DATA_SCHEMA.md.
public struct BackupPayload: Codable, Sendable, Equatable {
    public static let formatName = "conciergeclock-backup"
    public static let fileExtension = "conciergeclock"

    public var format: String
    /// Version of the backup layout (`SchemaVersion.backup`).
    public var schemaVersion: Int
    /// Database schema the data was exported from.
    public var databaseSchemaVersion: Int
    public var createdAt: Date
    public var appVersion: String
    public var settings: AppSettings
    public var alarms: [Alarm]
    public var wakeEvents: [WakeEvent]
    public var recommendations: [Recommendation]

    public init(
        createdAt: Date, appVersion: String, settings: AppSettings, alarms: [Alarm], wakeEvents: [WakeEvent],
        recommendations: [Recommendation], schemaVersion: Int = SchemaVersion.backup, databaseSchemaVersion: Int = SchemaVersion.database
    ) {
        self.format = Self.formatName
        self.schemaVersion = schemaVersion
        self.databaseSchemaVersion = databaseSchemaVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.settings = settings
        self.alarms = alarms
        self.wakeEvents = wakeEvents
        self.recommendations = recommendations
    }

    /// Problems that would break the data's links, or an empty list when it is consistent.
    /// Wake events and recommendations may point at deleted alarms (the link is cleared on
    /// restore), so only duplicate ids count.
    public var integrityIssues: [String] {
        var issues: [String] = []
        if Set(alarms.map(\.id)).count != alarms.count { issues.append("duplicate alarm") }
        if Set(wakeEvents.map(\.id)).count != wakeEvents.count { issues.append("duplicate wake event") }
        if Set(recommendations.map(\.id)).count != recommendations.count { issues.append("duplicate recommendation") }
        return issues
    }

    // MARK: Encoding

    /// Pretty-printed, sorted-key JSON with ISO-8601 dates: readable and diff-friendly.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(BackupDates.format(date))
        }
        return try encoder.encode(self)
    }

    /// Reads a backup file, upgrading older layouts (see `BackupMigrator`).
    public static func decode(_ data: Data) throws -> BackupPayload {
        try BackupMigrator.decode(data)
    }

    /// "ConciergeClock Backup 2026-11-27 0712.conciergeclock"
    public static func fileName(at date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let stamp = String(format: "%04d-%02d-%02d %02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0)
        return "ConciergeClock Backup \(stamp).\(fileExtension)"
    }
}

/// Why a backup could not be read or restored.
public enum BackupError: Error, Sendable, Equatable {
    /// Not a ConciergeClock backup (or damaged).
    case notABackup
    /// Made by a newer version of ConciergeClock.
    case newerVersion
    /// The data's links don't add up (damaged or edited file).
    case inconsistent
    case writeFailed
}

/// Upgrades backups written by older versions to the current layout before decoding.
///
/// Each future layout change adds a step `upgrade(fromVersion:)` that rewrites the JSON
/// object of version N into version N + 1, so a file from any older version opens.
public enum BackupMigrator {
    public static func decode(_ data: Data) throws -> BackupPayload {
        guard var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object["format"] as? String == BackupPayload.formatName,
              var version = object["schemaVersion"] as? Int else { throw BackupError.notABackup }
        guard version <= SchemaVersion.backup else { throw BackupError.newerVersion }
        while version < SchemaVersion.backup {
            object = upgrade(object, fromVersion: version)
            version += 1
            object["schemaVersion"] = version
        }
        let upgraded = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = BackupDates.parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(text)")
            }
            return date
        }
        do {
            return try decoder.decode(BackupPayload.self, from: upgraded)
        } catch {
            throw BackupError.notABackup
        }
    }

    /// Rewrites a backup of `version` into `version + 1`. Version 1 is the first layout, so
    /// there is nothing to upgrade yet.
    static func upgrade(_ object: [String: Any], fromVersion version: Int) -> [String: Any] {
        object
    }
}

/// ISO-8601 timestamps with milliseconds, in UTC ("2026-11-27T07:12:00.000Z"), as in
/// FocusFound's and PrepPilot's data contracts.
public enum BackupDates {
    public static func format(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    public static func parse(_ text: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) { return date }
        return try? Date.ISO8601FormatStyle().parse(text)
    }
}
