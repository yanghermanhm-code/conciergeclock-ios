import Foundation

/// How an alarm was finally stopped. Raw values are stored, so never rename a case.
public enum DismissMethod: String, Codable, Sendable, CaseIterable, Hashable {
    /// A spoken dismiss phrase ("I'm awake", "stop alarm").
    case voice
    /// The big Dismiss button in the app.
    case button
    /// The Stop button on the Lock Screen / Dynamic Island (AlarmKit).
    case system
    /// Never dismissed: the alarm timed out.
    case missed
}

/// One alarm cycle, from the first ring to the dismissal. Written by the alarm session
/// (Phase 1b/3); read by Trends and the Advisor. Holds times and counts only — never calendar
/// text, never what was said (docs/DECISIONS.md, privacy).
public struct WakeEvent: Codable, Sendable, Hashable, Identifiable {
    public var id: RecordID
    public var schemaVersion: Int
    /// The alarm that rang (nil if it was deleted since).
    public var alarmID: RecordID?
    /// The alarm's label when it rang.
    public var alarmLabel: String
    public var scheduledAt: Date
    /// When the alarm was dismissed (nil when missed).
    public var dismissedAt: Date?
    public var dismissMethod: DismissMethod
    public var snoozeCount: Int
    /// Total minutes added by snoozes.
    public var snoozedMinutes: Int
    /// The app's alarm volume used (0…1), if the app controlled it.
    public var volume: Double?
    /// The ambient sound playing overnight (nil = none).
    public var ambientSoundID: String?
    /// The wake sound used.
    public var wakeSoundID: String?
    /// Whether Nightstand Mode was on (full conversation) rather than the AlarmKit fallback.
    public var nightstandMode: Bool
    public var awakeCheck: AwakeCheckResult
    /// The score at the time it was logged (rules can change later; Trends can re-score).
    public var score: Int
    public var isSuccess: Bool
    /// The day of `scheduledAt` in the user's time zone.
    public var dateKey: DayKey
    public var createdAt: Date

    public init(
        id: RecordID = .make(), alarmID: RecordID?, alarmLabel: String, scheduledAt: Date, dismissedAt: Date?,
        dismissMethod: DismissMethod, snoozeCount: Int, snoozedMinutes: Int, volume: Double? = nil,
        ambientSoundID: String? = nil, wakeSoundID: String? = nil, nightstandMode: Bool = false,
        awakeCheck: AwakeCheckResult = .notAsked, rules: WakeScoreRules = .default,
        calendar: Calendar = .current, createdAt: Date = Date()
    ) {
        self.id = id
        self.schemaVersion = SchemaVersion.wakeEvent
        self.alarmID = alarmID
        self.alarmLabel = alarmLabel
        self.scheduledAt = scheduledAt
        self.dismissedAt = dismissedAt
        self.dismissMethod = dismissMethod
        self.snoozeCount = max(0, snoozeCount)
        self.snoozedMinutes = max(0, snoozedMinutes)
        self.volume = volume.map { $0.clamped(to: 0...1) }
        self.ambientSoundID = ambientSoundID
        self.wakeSoundID = wakeSoundID
        self.nightstandMode = nightstandMode
        self.awakeCheck = awakeCheck
        self.dateKey = DayKey(scheduledAt, calendar: calendar)
        self.createdAt = createdAt
        self.score = 0
        self.isSuccess = false
        rescore(rules: rules)
    }

    /// Actual wake minus the scheduled alarm, in minutes (negative = woke early). Nil when the
    /// alarm was missed.
    public var varianceMinutes: Double? {
        dismissedAt.map { $0.timeIntervalSince(scheduledAt) / 60 }
    }

    /// Recomputes `score` and `isSuccess` with `rules`. A missed alarm scores 0.
    public mutating func rescore(rules: WakeScoreRules) {
        guard dismissMethod != .missed, let variance = varianceMinutes else {
            score = 0
            isSuccess = false
            return
        }
        let result = WakeScore.compute(minutesLate: variance, snoozes: snoozeCount, check: awakeCheck, rules: rules)
        score = result.value
        isSuccess = result.isSuccess
    }
}

/// What the Wake Optimization Advisor suggested. Raw values are stored, so never rename a case.
public enum RecommendationKind: String, Codable, Sendable, CaseIterable, Hashable {
    case raiseVolume
    case addRampUp
    case clearerWakeSound
    case softenVolume
    case keepSettings
    case tryAmbientSound
    case stopAmbientSound
    case earlierBedtime
}

/// What happened to a suggestion. Raw values are stored, so never rename a case.
public enum RecommendationStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case offered
    /// Running as a 7-night experiment.
    case testing
    case applied
    case dismissed
}

/// One Advisor suggestion and its outcome (Phase 5). Suggestions never change settings
/// without a tap.
public struct Recommendation: Codable, Sendable, Hashable, Identifiable {
    public var id: RecordID
    public var schemaVersion: Int
    public var kind: RecommendationKind
    public var status: RecommendationStatus
    /// The alarm it is about (nil = all alarms).
    public var alarmID: RecordID?
    /// Kind-specific values, e.g. ["from": "0.6", "to": "0.75"] or ["sound": "noise.brown"].
    public var parameters: [String: String]
    /// For experiments: the first and last day of the test.
    public var experimentStart: DayKey?
    public var experimentEnd: DayKey?
    public var createdAt: Date
    public var resolvedAt: Date?

    public init(
        id: RecordID = .make(), kind: RecommendationKind, status: RecommendationStatus = .offered, alarmID: RecordID? = nil,
        parameters: [String: String] = [:], experimentStart: DayKey? = nil, experimentEnd: DayKey? = nil,
        createdAt: Date = Date(), resolvedAt: Date? = nil
    ) {
        self.id = id
        self.schemaVersion = SchemaVersion.recommendation
        self.kind = kind
        self.status = status
        self.alarmID = alarmID
        self.parameters = parameters
        self.experimentStart = experimentStart
        self.experimentEnd = experimentEnd
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }
}
