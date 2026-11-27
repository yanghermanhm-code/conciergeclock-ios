import Foundation

/// How a morning is scored (0–100). Agreed defaults (docs/DECISIONS.md):
/// start at 100; −4 per minute late after a 2-minute grace period, at most −60; −10 per snooze;
/// −15 if the "Are you really up?" check went unanswered. 80 or more counts as a success.
/// Every number can be changed in Settings.
public struct WakeScoreRules: Codable, Sendable, Hashable {
    /// Minutes after the alarm that still count as on time.
    public var graceMinutes: Int
    /// Points lost for each whole minute late after the grace period.
    public var pointsPerLateMinute: Int
    /// Most points lost for lateness.
    public var maxLatePenalty: Int
    /// Points lost for each snooze.
    public var pointsPerSnooze: Int
    /// Points lost when the "Are you really up?" check was missed.
    public var missedCheckPenalty: Int
    /// A score at or above this counts as a successful wake.
    public var successThreshold: Int

    public init(
        graceMinutes: Int = 2, pointsPerLateMinute: Int = 4, maxLatePenalty: Int = 60,
        pointsPerSnooze: Int = 10, missedCheckPenalty: Int = 15, successThreshold: Int = 80
    ) {
        self.graceMinutes = graceMinutes
        self.pointsPerLateMinute = pointsPerLateMinute
        self.maxLatePenalty = maxLatePenalty
        self.pointsPerSnooze = pointsPerSnooze
        self.missedCheckPenalty = missedCheckPenalty
        self.successThreshold = successThreshold
    }

    public static let `default` = WakeScoreRules()

    /// The ranges Settings offers; stored values are clamped to them when read.
    public static let graceRange = 0...30
    public static let lateMinuteRange = 0...20
    public static let maxLateRange = 0...100
    public static let snoozeRange = 0...50
    public static let missedCheckRange = 0...50
    public static let thresholdRange = 0...100

    /// The rules with every value inside its allowed range.
    public var clamped: WakeScoreRules {
        WakeScoreRules(
            graceMinutes: graceMinutes.clamped(to: Self.graceRange),
            pointsPerLateMinute: pointsPerLateMinute.clamped(to: Self.lateMinuteRange),
            maxLatePenalty: maxLatePenalty.clamped(to: Self.maxLateRange),
            pointsPerSnooze: pointsPerSnooze.clamped(to: Self.snoozeRange),
            missedCheckPenalty: missedCheckPenalty.clamped(to: Self.missedCheckRange),
            successThreshold: successThreshold.clamped(to: Self.thresholdRange)
        )
    }
}

/// The score of one morning and how it was reached, for the Trends tab and the Advisor.
public struct WakeScore: Codable, Sendable, Hashable {
    public var value: Int
    public var latePenalty: Int
    public var snoozePenalty: Int
    public var checkPenalty: Int
    public var isSuccess: Bool

    public init(value: Int, latePenalty: Int, snoozePenalty: Int, checkPenalty: Int, isSuccess: Bool) {
        self.value = value
        self.latePenalty = latePenalty
        self.snoozePenalty = snoozePenalty
        self.checkPenalty = checkPenalty
        self.isSuccess = isSuccess
    }

    /// Scores a morning.
    ///
    /// - Parameters:
    ///   - minutesLate: actual wake minus the scheduled alarm, in minutes (negative = early;
    ///     early and on-time wakes lose nothing). Partial minutes round down.
    ///   - snoozes: how many times the alarm was snoozed.
    ///   - check: the "Are you really up?" result.
    public static func compute(minutesLate: Double, snoozes: Int, check: AwakeCheckResult, rules: WakeScoreRules = .default) -> WakeScore {
        let rules = rules.clamped
        let lateMinutes = max(0, Int(minutesLate.rounded(.down)) - rules.graceMinutes)
        let latePenalty = min(rules.maxLatePenalty, lateMinutes * rules.pointsPerLateMinute)
        let snoozePenalty = max(0, snoozes) * rules.pointsPerSnooze
        let checkPenalty = check == .missed ? rules.missedCheckPenalty : 0
        let value = max(0, min(100, 100 - latePenalty - snoozePenalty - checkPenalty))
        return WakeScore(
            value: value, latePenalty: latePenalty, snoozePenalty: snoozePenalty, checkPenalty: checkPenalty,
            isSuccess: value >= rules.successThreshold
        )
    }
}

/// The result of the "Are you really up?" check a few minutes after dismissing.
/// Raw values are stored, so never rename a case.
public enum AwakeCheckResult: String, Codable, Sendable, CaseIterable, Hashable {
    /// The check was off, or the alarm was dismissed in a way that skips it.
    case notAsked
    /// Answered in time.
    case passed
    /// Not answered: the alarm rang again.
    case missed
}
