@testable import ConciergeCore
import XCTest

final class WakeScoreTests: XCTestCase {
    func testOnTimeWithoutSnoozesScoresFull() {
        let score = WakeScore.compute(minutesLate: 0, snoozes: 0, check: .passed)
        XCTAssertEqual(score.value, 100)
        XCTAssertTrue(score.isSuccess)
    }

    func testEarlyWakeLosesNothing() {
        XCTAssertEqual(WakeScore.compute(minutesLate: -12, snoozes: 0, check: .notAsked).value, 100)
    }

    func testGracePeriodThenFourPointsPerMinute() {
        XCTAssertEqual(WakeScore.compute(minutesLate: 2.9, snoozes: 0, check: .notAsked).value, 100)
        XCTAssertEqual(WakeScore.compute(minutesLate: 3, snoozes: 0, check: .notAsked).value, 96)
        XCTAssertEqual(WakeScore.compute(minutesLate: 7.5, snoozes: 0, check: .notAsked).value, 80)
    }

    func testLatePenaltyIsCapped() {
        let score = WakeScore.compute(minutesLate: 90, snoozes: 0, check: .notAsked)
        XCTAssertEqual(score.latePenalty, 60)
        XCTAssertEqual(score.value, 40)
        XCTAssertFalse(score.isSuccess)
    }

    func testSnoozesAndMissedCheck() {
        let score = WakeScore.compute(minutesLate: 12, snoozes: 2, check: .missed)
        // 12 − 2 grace = 10 min × 4 = 40; 2 snoozes = 20; missed check = 15.
        XCTAssertEqual(score.latePenalty, 40)
        XCTAssertEqual(score.snoozePenalty, 20)
        XCTAssertEqual(score.checkPenalty, 15)
        XCTAssertEqual(score.value, 25)
    }

    func testScoreNeverBelowZero() {
        XCTAssertEqual(WakeScore.compute(minutesLate: 60, snoozes: 9, check: .missed).value, 0)
    }

    func testSuccessThresholdIsInclusive() {
        // One snooze, on time: 90 ≥ 80.
        XCTAssertTrue(WakeScore.compute(minutesLate: 0, snoozes: 1, check: .passed).isSuccess)
        // Two snoozes and 2 minutes past grace: 100 − 20 − 8 = 72.
        XCTAssertFalse(WakeScore.compute(minutesLate: 4, snoozes: 2, check: .passed).isSuccess)
        let strict = WakeScoreRules(successThreshold: 95)
        XCTAssertFalse(WakeScore.compute(minutesLate: 0, snoozes: 1, check: .passed, rules: strict).isSuccess)
    }

    func testRulesAreClamped() {
        let wild = WakeScoreRules(graceMinutes: -5, pointsPerLateMinute: 500, maxLatePenalty: 900, pointsPerSnooze: -3, missedCheckPenalty: 99, successThreshold: 140)
        let clamped = wild.clamped
        XCTAssertEqual(clamped.graceMinutes, 0)
        XCTAssertEqual(clamped.pointsPerLateMinute, 20)
        XCTAssertEqual(clamped.maxLatePenalty, 100)
        XCTAssertEqual(clamped.pointsPerSnooze, 0)
        XCTAssertEqual(clamped.missedCheckPenalty, 50)
        XCTAssertEqual(clamped.successThreshold, 100)
    }

    func testWakeEventScoresItselfAndMissedScoresZero() {
        let scheduled = Date(timeIntervalSince1970: 1_790_000_000)
        let event = WakeEvent(
            alarmID: "A", alarmLabel: "Work", scheduledAt: scheduled, dismissedAt: scheduled.addingTimeInterval(8 * 60),
            dismissMethod: .voice, snoozeCount: 1, snoozedMinutes: 5, awakeCheck: .passed
        )
        XCTAssertEqual(event.varianceMinutes, 8)
        XCTAssertEqual(event.score, 66) // 100 − (8 − 2) × 4 − 10
        XCTAssertFalse(event.isSuccess)

        let missed = WakeEvent(alarmID: nil, alarmLabel: "", scheduledAt: scheduled, dismissedAt: nil, dismissMethod: .missed, snoozeCount: 0, snoozedMinutes: 0)
        XCTAssertNil(missed.varianceMinutes)
        XCTAssertEqual(missed.score, 0)
        XCTAssertFalse(missed.isSuccess)
    }
}
