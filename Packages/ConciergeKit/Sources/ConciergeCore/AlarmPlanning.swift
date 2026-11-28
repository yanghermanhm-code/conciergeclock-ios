import Foundation

/// One ring of one alarm: what AlarmKit is asked to schedule. Its id is derived from the alarm
/// and the time (`AlarmPlanner.occurrenceID`), so planning the same ring twice gives the same id
/// and the scheduler can compare what is wanted with what is already scheduled.
public struct PlannedRing: Sendable, Hashable {
    public var id: UUID
    public var alarmID: RecordID
    public var fireDate: Date

    public init(id: UUID, alarmID: RecordID, fireDate: Date) {
        self.id = id
        self.alarmID = alarmID
        self.fireDate = fireDate
    }
}

/// Decides which rings to schedule. Pure and deterministic, so it is unit-tested; the app's
/// AlarmScheduler hands the result to AlarmKit.
public enum AlarmPlanner {
    /// Rings per alarm kept scheduled ahead. Two means tomorrow's ring still exists even if
    /// the app does not run between two mornings (every Stop also re-plans).
    public static let ringsAhead = 2
    /// How far ahead rings are planned.
    public static let horizonDays = 8

    /// The next rings of every enabled alarm after `now`, honouring repeat days, the one-off
    /// skip and — for alarms that skip days off — `isDayOff`. Sorted by time.
    public static func plan(
        alarms: [Alarm], after now: Date, calendar: Calendar = .current,
        isDayOff: (DayKey) -> Bool = { _ in false }
    ) -> [PlannedRing] {
        var rings: [PlannedRing] = []
        let limit = calendar.date(byAdding: .day, value: horizonDays, to: now) ?? now
        for alarm in alarms where alarm.isEnabled {
            var cursor = now
            var found = 0
            // Each step moves past one candidate ring, so the loop always ends.
            // An alarm for an exact date is scheduled however far ahead it is, and rings on that
            // date even if it looks like a day off (the person chose it).
            if alarm.isDated {
                if let fire = alarm.nextFireDate(after: now, calendar: calendar) {
                    // Set for the current minute: ring a few seconds from now. The id stays tied to
                    // the alarm's own minute, so re-planning does not schedule it twice.
                    let ring = max(fire, now.addingTimeInterval(3))
                    rings.append(PlannedRing(id: occurrenceID(alarmID: alarm.id, fireDate: fire), alarmID: alarm.id, fireDate: ring))
                }
                continue
            }
            while found < ringsAhead, let next = alarm.nextFireDate(after: cursor, calendar: calendar), next <= limit {
                cursor = next
                if alarm.skipOnDaysOff, isDayOff(DayKey(next, calendar: calendar)) { continue }
                rings.append(PlannedRing(id: occurrenceID(alarmID: alarm.id, fireDate: next), alarmID: alarm.id, fireDate: next))
                found += 1
                // A one-off alarm rings once.
                if !alarm.repeats { break }
            }
        }
        return rings.sorted { $0.fireDate < $1.fireDate }
    }

    /// A stable UUID for one ring (two FNV-1a style 64-bit hashes over "alarmID|seconds"),
    /// marked as a version-8 (custom) UUID. Same input, same id: no randomness.
    public static func occurrenceID(alarmID: RecordID, fireDate: Date) -> UUID {
        let text = "\(alarmID)|\(Int(fireDate.timeIntervalSince1970.rounded()))"
        var high: UInt64 = 0xcbf2_9ce4_8422_2325
        var low: UInt64 = 0x8422_2325_cbf2_9ce4
        for byte in text.utf8 {
            high = (high ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
            low = (low ^ UInt64(byte) ^ (high >> 29)) &* 0x0000_0100_0000_01B3
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            bytes[index] = UInt8(truncatingIfNeeded: high >> UInt64(8 * (7 - index)))
            bytes[8 + index] = UInt8(truncatingIfNeeded: low >> UInt64(8 * (7 - index)))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x80
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// Snoozes inferred from how long the alarm ran: with the system's snooze button each
    /// snooze adds exactly `snoozeMinutes`, so a Stop after 11 minutes with a 5-minute snooze
    /// means two snoozes. Used when the snooze taps themselves were not reported.
    public static func inferredSnoozes(scheduledAt: Date, stoppedAt: Date, snoozeMinutes: Int) -> Int {
        guard snoozeMinutes > 0 else { return 0 }
        let elapsed = stoppedAt.timeIntervalSince(scheduledAt)
        guard elapsed > 0 else { return 0 }
        return Int(elapsed / Double(snoozeMinutes * 60))
    }
}

/// An all-day calendar item used to recognise days off. Only the titles are read, on the
/// iPhone, and never stored.
public struct AllDayItem: Sendable, Hashable {
    public var title: String
    public var calendarTitle: String

    public init(title: String, calendarTitle: String) {
        self.title = title
        self.calendarTitle = calendarTitle
    }
}

/// Whether a day is a day off: any all-day item in a holiday calendar, or whose title contains
/// one of the user's day-off words (whole words, case- and accent-insensitive).
public enum DayOffRules {
    public static func isDayOff(_ items: [AllDayItem], keywords: [String]) -> Bool {
        let words = keywords.compactMap(\.nonBlank).map(normalize)
        return items.contains { item in
            if isHolidayCalendar(item.calendarTitle) { return true }
            let title = normalize(item.title)
            let spaced = " " + tokens(title) + " "
            return words.contains { word in
                // Latin-script words match whole words ("PTO" is not in "Crypto"); other
                // scripts (no spaces between words) match anywhere in the title.
                word.unicodeScalars.allSatisfy(\.isASCII) ? spaced.contains(" " + tokens(word) + " ") : title.contains(word)
            }
        }
    }

    /// Letters and digits only, words separated by single spaces.
    static func tokens(_ text: String) -> String {
        text.split(whereSeparator: { !($0.isLetter || $0.isNumber) }).joined(separator: " ")
    }

    /// Holiday calendars as iOS names them ("US Holidays", "Holidays in Canada", "Jours fériés"…).
    public static func isHolidayCalendar(_ title: String) -> Bool {
        let text = normalize(title)
        return ["holiday", "feries", "festivos", "feriados", "libur"].contains { text.contains($0) }
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}

/// What the widgets show, written by the app into the shared App Group folder.
public struct NextAlarmSnapshot: Codable, Sendable, Hashable {
    public var fireDate: Date?
    public var label: String
    public var enabledAlarmCount: Int
    /// The app's language, so the widgets match it.
    public var languageCode: String?
    public var updatedAt: Date

    public init(fireDate: Date?, label: String, enabledAlarmCount: Int, languageCode: String?, updatedAt: Date = Date()) {
        self.fireDate = fireDate
        self.label = label
        self.enabledAlarmCount = enabledAlarmCount
        self.languageCode = languageCode
        self.updatedAt = updatedAt
    }

    public static let fileName = "next-alarm.json"

    public func write(to folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: folder.appendingPathComponent(Self.fileName), options: .atomic)
    }

    public static func read(from folder: URL) -> NextAlarmSnapshot? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(fileName)) else { return nil }
        return try? JSONDecoder().decode(NextAlarmSnapshot.self, from: data)
    }
}
