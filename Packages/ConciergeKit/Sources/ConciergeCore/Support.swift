import Foundation

/// Identifier type shared by every stored record (an uppercase UUID string).
///
/// Strings rather than `UUID` values so that ids read the same in SQLite, JSON backups and
/// CSV exports, and compare correctly in SQL (GRDB stores bare `UUID`s as blobs).
public typealias RecordID = String

public extension RecordID {
    /// A new random identifier.
    static func make() -> RecordID { UUID().uuidString }
}

/// Current schema versions of every persisted or exported payload.
///
/// Rules: bump a version whenever the shape of that payload changes in a way older code
/// cannot read, and teach the matching decoder or migration how to upgrade older documents
/// (`BackupMigrator` for backups, `Migrations` for the database).
public enum SchemaVersion {
    /// SQLite database (also recorded in the `keyValue` table).
    public static let database = 2
    /// `AppSettings` document.
    public static let settings = 1
    /// Alarms.
    public static let alarm = 1
    /// Wake log entries.
    public static let wakeEvent = 1
    /// Scheduled rings (this iPhone only, not in backups).
    public static let occurrence = 1
    /// Wake Optimization Advisor recommendations.
    public static let recommendation = 1
    /// `.conciergeclock` JSON backups.
    public static let backup = 1
}

/// Decoding helpers that fall back to a default instead of failing the whole document.
/// Used by long-lived documents (settings) so files written by older or newer versions
/// always open.
public extension KeyedDecodingContainer {
    /// The decoded value for `key`, or `fallback` when the key is missing, null,
    /// of the wrong type, or holds an unknown enum value.
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        let decoded: T? = try? decodeIfPresent(T.self, forKey: key)
        return decoded ?? fallback
    }
}

public extension Comparable {
    /// The value limited to `range`.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// A calendar day in the user's time zone, written "YYYY-MM-DD". Used for the wake log and
/// trend charts: a wake-up counts for the day its alarm was scheduled.
public struct DayKey: RawRepresentable, Codable, Sendable, Hashable, Comparable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The day containing `date` in `calendar`'s time zone.
    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        rawValue = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Whole days from `self` to `other` (negative if `other` is earlier).
    public func days(to other: DayKey, calendar: Calendar = .current) -> Int? {
        guard let start = date(calendar: calendar), let end = other.date(calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    /// Midnight at the start of this day, or nil if the key is malformed.
    public func date(calendar: Calendar = .current) -> Date? {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

public extension String {
    /// The string with leading/trailing whitespace removed and inner runs of whitespace
    /// collapsed to single spaces.
    var collapsingWhitespace: String {
        split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// The string trimmed, or nil when nothing is left.
    var nonBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
