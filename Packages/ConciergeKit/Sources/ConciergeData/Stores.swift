import ConciergeCore
import Foundation
import GRDB

/// Alarms: read, observe, save and delete.
public struct AlarmStore: Sendable {
    public let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    static let ordered = Alarm.order(Column("hour"), Column("minute"), Column("createdAt"))

    /// Every alarm, earliest time of day first, re-emitted whenever one changes.
    public func observeAlarms() -> AsyncValueObservation<[Alarm]> {
        ValueObservation
            .tracking { db in try Self.ordered.fetchAll(db) }
            .values(in: database.writer)
    }

    public func all() throws -> [Alarm] {
        try database.writer.read { db in try Self.ordered.fetchAll(db) }
    }

    public func alarm(id: RecordID) throws -> Alarm? {
        try database.writer.read { db in try Alarm.fetchOne(db, key: id) }
    }

    /// Inserts or updates `alarm`, stamping `updatedAt`.
    @discardableResult
    public func save(_ alarm: Alarm, at now: Date = Date()) throws -> Alarm {
        var saved = alarm
        saved.updatedAt = now
        try database.writer.write { db in try saved.save(db) }
        return saved
    }

    /// Deletes the alarm. Its wake log stays (the link is cleared).
    public func delete(id: RecordID) throws {
        _ = try database.writer.write { db in try Alarm.deleteOne(db, key: id) }
    }

    public func count() throws -> Int {
        try database.writer.read { db in try Alarm.fetchCount(db) }
    }
}

/// The wake log: one entry per alarm cycle.
public struct WakeLogStore: Sendable {
    public let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func insert(_ event: WakeEvent) throws {
        try database.writer.write { db in try event.insert(db) }
    }

    /// Entries from `start` (inclusive) on, oldest first; all entries when `start` is nil.
    public func events(since start: DayKey? = nil) throws -> [WakeEvent] {
        try database.writer.read { db in try Self.request(since: start).fetchAll(db) }
    }

    /// Like `events(since:)`, re-emitted whenever the log changes.
    public func observeEvents(since start: DayKey? = nil) -> AsyncValueObservation<[WakeEvent]> {
        ValueObservation
            .tracking { db in try Self.request(since: start).fetchAll(db) }
            .values(in: database.writer)
    }

    public func count() throws -> Int {
        try database.writer.read { db in try WakeEvent.fetchCount(db) }
    }

    /// Re-scores every entry with new rules (after the wake score is changed in Settings).
    public func rescoreAll(rules: WakeScoreRules) throws {
        try database.writer.write { db in
            for var event in try WakeEvent.fetchAll(db) {
                event.rescore(rules: rules)
                try event.update(db)
            }
        }
    }

    /// Deletes the whole log (Settings › Wake log › Erase).
    public func deleteAll() throws {
        _ = try database.writer.write { db in try WakeEvent.deleteAll(db) }
    }

    static func request(since start: DayKey?) -> QueryInterfaceRequest<WakeEvent> {
        var request = WakeEvent.order(Column("scheduledAt"))
        if let start {
            request = request.filter(Column("dateKey") >= start.rawValue)
        }
        return request
    }
}

/// The Wake Optimization Advisor's suggestions and their outcomes.
public struct RecommendationStore: Sendable {
    public let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func all() throws -> [Recommendation] {
        try database.writer.read { db in try Recommendation.order(Column("createdAt").desc).fetchAll(db) }
    }

    public func save(_ recommendation: Recommendation) throws {
        try database.writer.write { db in try recommendation.save(db) }
    }
}

/// Rings handed to AlarmKit (this iPhone only) and their outcome.
public struct OccurrenceStore: Sendable {
    public let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func occurrence(id: RecordID) throws -> AlarmOccurrence? {
        try database.writer.read { db in try AlarmOccurrence.fetchOne(db, key: id) }
    }

    /// Rings still waiting for an outcome, earliest first.
    public func scheduled() throws -> [AlarmOccurrence] {
        try database.writer.read { db in
            try AlarmOccurrence
                .filter(Column("status") == OccurrenceStatus.scheduled.rawValue)
                .order(Column("scheduledAt"))
                .fetchAll(db)
        }
    }

    /// Records a ring as scheduled (no change if it is already known).
    public func insertIfNew(_ occurrence: AlarmOccurrence) throws {
        try database.writer.write { db in
            if try AlarmOccurrence.fetchOne(db, key: occurrence.id) == nil {
                try occurrence.insert(db)
            }
        }
    }

    public func setStatus(_ status: OccurrenceStatus, id: RecordID, at now: Date = Date()) throws {
        try database.writer.write { db in
            guard var occurrence = try AlarmOccurrence.fetchOne(db, key: id) else { return }
            occurrence.status = status
            occurrence.updatedAt = now
            try occurrence.update(db)
        }
    }

    /// Counts one Snooze tap.
    public func addSnooze(id: RecordID, at now: Date = Date()) throws {
        try database.writer.write { db in
            guard var occurrence = try AlarmOccurrence.fetchOne(db, key: id), occurrence.status == .scheduled else { return }
            occurrence.snoozeCount += 1
            occurrence.updatedAt = now
            try occurrence.update(db)
        }
    }

    /// Writes the wake log entry for a ring and marks it finished (or missed), in one
    /// transaction. Does nothing if the ring already has an outcome, so a Stop reported twice
    /// is logged once.
    @discardableResult
    public func finish(
        id: RecordID, stoppedAt: Date?, method: DismissMethod, rules: WakeScoreRules, now: Date = Date()
    ) throws -> WakeEvent? {
        try database.writer.write { db in
            guard var occurrence = try AlarmOccurrence.fetchOne(db, key: id), occurrence.status == .scheduled else { return nil }
            let alarm = try Alarm.fetchOne(db, key: occurrence.alarmID)
            let event = occurrence.wakeEvent(alarm: alarm, stoppedAt: stoppedAt, method: method, rules: rules, now: now)
            if try WakeEvent.fetchOne(db, key: event.id) == nil {
                try event.insert(db)
            }
            occurrence.status = stoppedAt == nil ? .missed : .finished
            occurrence.updatedAt = now
            try occurrence.update(db)
            return event
        }
    }

    /// "Remind me again" rings still to come (kept when the scheduler re-plans).
    public func pendingFollowUps(after date: Date) throws -> [AlarmOccurrence] {
        try database.writer.read { db in
            try AlarmOccurrence
                .filter(Column("status") == OccurrenceStatus.scheduled.rawValue)
                .filter(Column("originID") != nil)
                .filter(Column("scheduledAt") > date)
                .fetchAll(db)
        }
    }

    /// The ring whose morning a ring belongs to (itself, or the ring that woke the person first).
    public func origin(of id: RecordID) throws -> AlarmOccurrence? {
        guard let ring = try occurrence(id: id) else { return nil }
        guard let originID = ring.originID else { return ring }
        return try occurrence(id: originID) ?? ring
    }

    /// "Remind me again": counts a snooze on the first ring of this morning and records the new
    /// ring (to be handed to AlarmKit by the scheduler). The ring that just sounded is closed.
    @discardableResult
    public func addFollowUp(after ringID: RecordID, newRingID: RecordID, at fireDate: Date, now: Date = Date()) throws -> AlarmOccurrence? {
        try database.writer.write { db in
            guard let ring = try AlarmOccurrence.fetchOne(db, key: ringID) else { return nil }
            let originID = ring.originID ?? ring.id
            guard var origin = try AlarmOccurrence.fetchOne(db, key: originID) else { return nil }
            origin.snoozeCount += 1
            origin.updatedAt = now
            try origin.update(db)
            if ring.originID != nil, var closed = try AlarmOccurrence.fetchOne(db, key: ringID) {
                closed.status = .finished
                closed.updatedAt = now
                try closed.update(db)
            }
            let followUp = AlarmOccurrence(
                id: newRingID, alarmID: ring.alarmID, scheduledAt: fireDate, snoozeMinutes: ring.snoozeMinutes,
                originID: originID, createdAt: now
            )
            try followUp.insert(db)
            return followUp
        }
    }

    /// Ends the morning a ring belongs to: logs it on the first ring (once) and closes every
    /// "remind me again" ring of that morning.
    @discardableResult
    public func finishMorning(ringID: RecordID, stoppedAt: Date?, method: DismissMethod, rules: WakeScoreRules, now: Date = Date()) throws -> WakeEvent? {
        let originID = try origin(of: ringID)?.id ?? ringID
        let event = try finish(id: originID, stoppedAt: stoppedAt, method: method, rules: rules, now: now)
        try database.writer.write { db in
            let rings = try AlarmOccurrence
                .filter(Column("originID") == originID || Column("id") == ringID)
                .filter(Column("status") == OccurrenceStatus.scheduled.rawValue)
                .fetchAll(db)
            for var ring in rings {
                ring.status = stoppedAt == nil ? .missed : .finished
                ring.updatedAt = now
                try ring.update(db)
            }
        }
        return event
    }

    /// Deletes outcomes older than 60 days (the wake log keeps the history).
    public func pruneFinished(before date: Date) throws {
        _ = try database.writer.write { db in
            try AlarmOccurrence
                .filter(Column("status") != OccurrenceStatus.scheduled.rawValue)
                .filter(Column("scheduledAt") < date)
                .deleteAll(db)
        }
    }
}
