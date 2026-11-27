import Foundation

/// The state of one scheduled ring. Raw values are stored, so never rename a case.
public enum OccurrenceStatus: String, Codable, Sendable, CaseIterable, Hashable {
    /// Handed to AlarmKit, not rung yet (or ringing now).
    case scheduled
    /// Stopped: its wake log entry is written.
    case finished
    /// Never stopped: logged as missed.
    case missed
    /// Withdrawn before it rang (alarm edited, skipped, disabled or deleted).
    case cancelled
}

/// One ring handed to AlarmKit and what happened to it. Lives only on this iPhone (AlarmKit
/// ids are device-specific), so it is not part of backups; the outcome goes into the wake log.
public struct AlarmOccurrence: Codable, Sendable, Hashable, Identifiable {
    /// The AlarmKit alarm id (uppercase UUID string).
    public var id: RecordID
    public var schemaVersion: Int
    public var alarmID: RecordID
    public var scheduledAt: Date
    /// Snooze taps reported by the Snooze button.
    public var snoozeCount: Int
    /// The snooze length the ring was scheduled with.
    public var snoozeMinutes: Int
    public var status: OccurrenceStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: RecordID, alarmID: RecordID, scheduledAt: Date, snoozeMinutes: Int, snoozeCount: Int = 0,
        status: OccurrenceStatus = .scheduled, createdAt: Date = Date()
    ) {
        self.id = id
        self.schemaVersion = SchemaVersion.occurrence
        self.alarmID = alarmID
        self.scheduledAt = scheduledAt
        self.snoozeCount = max(0, snoozeCount)
        self.snoozeMinutes = snoozeMinutes.clamped(to: Snooze.minuteRange)
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// A ring not stopped this long after it was due counts as missed.
    public static let missedAfter: TimeInterval = 3 * 3600

    /// The wake log entry for this ring, stopped at `stoppedAt` (nil = missed). Snoozes are
    /// the reported taps, or — when taps were not reported — what the elapsed time implies.
    public func wakeEvent(
        alarm: Alarm?, stoppedAt: Date?, method: DismissMethod, awakeCheck: AwakeCheckResult = .notAsked,
        rules: WakeScoreRules, calendar: Calendar = .current, now: Date = Date()
    ) -> WakeEvent {
        let snoozes = stoppedAt.map {
            max(snoozeCount, AlarmPlanner.inferredSnoozes(scheduledAt: scheduledAt, stoppedAt: $0, snoozeMinutes: snoozeMinutes))
        } ?? snoozeCount
        return WakeEvent(
            id: id,
            alarmID: alarm?.id,
            alarmLabel: alarm?.label ?? "",
            scheduledAt: scheduledAt,
            dismissedAt: stoppedAt,
            dismissMethod: stoppedAt == nil ? .missed : method,
            snoozeCount: snoozes,
            snoozedMinutes: snoozes * snoozeMinutes,
            ambientSoundID: alarm?.ambientSoundID,
            wakeSoundID: alarm?.soundID,
            nightstandMode: false,
            awakeCheck: awakeCheck,
            rules: rules,
            calendar: calendar,
            createdAt: now
        )
    }
}
