import Foundation

/// Days of the week as stored: 1 = Sunday … 7 = Saturday (the same numbering as
/// `Calendar.component(.weekday, from:)` in the Gregorian calendar).
public typealias Weekday = Int

/// Common sets of weekdays.
public enum Weekdays {
    public static let all: [Weekday] = [1, 2, 3, 4, 5, 6, 7]
    public static let workWeek: Set<Weekday> = [2, 3, 4, 5, 6]
    public static let weekend: Set<Weekday> = [1, 7]
}

/// What kind of alarm this is. Raw values are stored, so never rename a case.
public enum AlarmKind: String, Codable, Sendable, CaseIterable, Hashable {
    /// A wake-up alarm with the morning briefing.
    case wakeUp
    /// A spoken check-in at a set time (no snooze loop).
    case checkIn
}

/// One alarm the user set. Scheduling with AlarmKit arrives in Phase 1b; this is the stored
/// shape, so it already holds every per-alarm option the later phases use.
public struct Alarm: Codable, Sendable, Hashable, Identifiable {
    public var id: RecordID
    public var schemaVersion: Int
    public var kind: AlarmKind
    /// Shown in the list and spoken ("Gym"). May be empty.
    public var label: String
    /// Local time of day.
    public var hour: Int
    public var minute: Int
    /// Days it repeats on (see `Weekday`). Empty = rings once, at the next `hour:minute`.
    public var repeatDays: Set<Weekday>
    public var isEnabled: Bool
    /// Snooze length for this alarm in minutes, or nil for the default in Settings.
    public var snoozeMinutes: Int?
    /// Per-alarm persona overrides (nil = the default in Settings).
    public var toneOverride: PersonaTone?
    public var accentOverride: VoiceAccent?
    public var lengthOverride: BriefingLength?
    /// The wake sound (Phase 4 catalogue id).
    public var soundID: String
    /// Seconds over which the alarm sound rises to full volume (0 = full volume at once).
    public var rampUpSeconds: Int
    /// The ambient sound played in Nightstand Mode before this alarm, or nil for none.
    public var ambientSoundID: String?
    /// Skip only the next occurrence on this day.
    public var skipDay: DayKey?
    /// Skip days that look like days off in the calendar (holidays, "Vacation", "Day off").
    public var skipOnDaysOff: Bool
    /// Most snoozes before the butler stops offering one (nil = no limit).
    public var snoozeLimit: Int?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: RecordID = .make(), kind: AlarmKind = .wakeUp, label: String = "", hour: Int = 7, minute: Int = 0,
        repeatDays: Set<Weekday> = Weekdays.workWeek, isEnabled: Bool = true, snoozeMinutes: Int? = nil,
        toneOverride: PersonaTone? = nil, accentOverride: VoiceAccent? = nil, lengthOverride: BriefingLength? = nil,
        soundID: String = Alarm.defaultSoundID, rampUpSeconds: Int = 30, ambientSoundID: String? = nil,
        skipDay: DayKey? = nil, skipOnDaysOff: Bool = true, snoozeLimit: Int? = nil, createdAt: Date = Date(), updatedAt: Date? = nil
    ) {
        self.id = id
        self.schemaVersion = SchemaVersion.alarm
        self.kind = kind
        self.label = label
        self.hour = hour.clamped(to: 0...23)
        self.minute = minute.clamped(to: 0...59)
        self.repeatDays = repeatDays.filter { (1...7).contains($0) }
        self.isEnabled = isEnabled
        self.snoozeMinutes = snoozeMinutes.map { $0.clamped(to: Snooze.minuteRange) }
        self.toneOverride = toneOverride
        self.accentOverride = accentOverride
        self.lengthOverride = lengthOverride
        self.soundID = soundID
        self.rampUpSeconds = rampUpSeconds.clamped(to: 0...300)
        self.ambientSoundID = ambientSoundID
        self.skipDay = skipDay
        self.skipOnDaysOff = skipOnDaysOff
        self.snoozeLimit = snoozeLimit.map { $0.clamped(to: 0...20) }
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    public static let defaultSoundID = "chime.soft"

    /// Minutes after midnight.
    public var minuteOfDay: Int { hour * 60 + minute }

    public var repeats: Bool { !repeatDays.isEmpty }

    /// The next time this alarm rings at or after `now`, honouring repeat days and the
    /// one-off skip (days off from the calendar are applied by the scheduler, which can read
    /// the calendar). Nil when disabled.
    public func nextFireDate(after now: Date, calendar: Calendar = .current) -> Date? {
        guard isEnabled else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        // Look up to 8 days ahead: enough for any weekly pattern plus one skipped day.
        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now else { continue }
            if repeats, !repeatDays.contains(calendar.component(.weekday, from: fire)) { continue }
            if let skipDay, DayKey(fire, calendar: calendar) == skipDay { continue }
            return fire
        }
        return nil
    }
}

/// Snooze options shared by Settings and the alarm editor.
public enum Snooze {
    /// The agreed default: 5 minutes.
    public static let defaultMinutes = 5
    /// Presets offered in pickers. Any value in `minuteRange` can be entered as a custom length.
    public static let presets = [1, 3, 5, 9, 10, 15, 20, 30]
    public static let minuteRange = 1...120
}
