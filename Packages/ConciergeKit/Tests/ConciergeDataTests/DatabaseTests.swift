import ConciergeCore
@testable import ConciergeData
import Foundation
import GRDB
import XCTest

final class DatabaseTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    // MARK: Schema

    func testMigrationsCreateEveryTableAndRecordVersion() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.read { db in
            for table in ["keyValue", "alarm", "wakeEvent", "recommendation", "alarmOccurrence"] {
                XCTAssertTrue(try db.tableExists(table), table)
            }
        }
        XCTAssertEqual(try db.storedSchemaVersion(), SchemaVersion.database)
    }

    func testDatabaseLivesInApplicationSupportNotCaches() throws {
        let url = try DatabaseLocation.resolveURL()
        XCTAssertTrue(url.path.contains("Application Support"), url.path)
        XCTAssertFalse(url.path.contains("Caches"), url.path)
    }

    func testReopeningOnDiskKeepsData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("concierge-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let first = try AppDatabase.open(at: url)
        try AlarmStore(database: first).save(Alarm(id: "A1", label: "Gym", hour: 6, minute: 15, createdAt: t0), at: t0)
        let second = try AppDatabase.open(at: url)
        XCTAssertEqual(try AlarmStore(database: second).alarm(id: "A1")?.label, "Gym")
    }

    // MARK: Settings

    func testSettingsRoundTripAndBookmarkStaysSeparate() throws {
        let db = try AppDatabase.inMemory()
        XCTAssertEqual(db.loadSettings(), .default)
        var settings = AppSettings()
        settings.tone = .child
        settings.defaultSnoozeMinutes = 9
        try db.saveSettings(settings)
        XCTAssertEqual(db.loadSettings(), settings)

        XCTAssertNil(db.loadAutoBackupBookmark())
        try db.saveAutoBackupBookmark(Data([1, 2, 3]))
        XCTAssertEqual(db.loadAutoBackupBookmark(), Data([1, 2, 3]))
        try db.saveAutoBackupBookmark(nil)
        XCTAssertNil(db.loadAutoBackupBookmark())
    }

    // MARK: Alarms and wake log

    func testAlarmsAreOrderedByTimeAndRepeatDaysSurvive() throws {
        let db = try AppDatabase.inMemory()
        let store = AlarmStore(database: db)
        try store.save(Alarm(id: "late", hour: 9, minute: 0, repeatDays: Weekdays.weekend, createdAt: t0))
        try store.save(Alarm(id: "early", hour: 6, minute: 30, repeatDays: [2, 4, 6], toneOverride: .unhinged, createdAt: t0))
        let alarms = try store.all()
        XCTAssertEqual(alarms.map(\.id), ["early", "late"])
        XCTAssertEqual(alarms[0].repeatDays, [2, 4, 6])
        XCTAssertEqual(alarms[0].toneOverride, .unhinged)
        XCTAssertEqual(alarms[1].repeatDays, Weekdays.weekend)
    }

    func testDeletingAnAlarmKeepsItsWakeLog() throws {
        let db = try AppDatabase.inMemory()
        try AlarmStore(database: db).save(Alarm(id: "A1", createdAt: t0))
        let log = WakeLogStore(database: db)
        try log.insert(WakeEvent(
            id: "E1", alarmID: "A1", alarmLabel: "Work", scheduledAt: t0, dismissedAt: t0.addingTimeInterval(60),
            dismissMethod: .button, snoozeCount: 0, snoozedMinutes: 0, createdAt: t0
        ))
        try AlarmStore(database: db).delete(id: "A1")
        let events = try log.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events[0].alarmID)
        XCTAssertEqual(events[0].alarmLabel, "Work")
    }

    func testRescoreAllUsesNewRules() throws {
        let db = try AppDatabase.inMemory()
        let log = WakeLogStore(database: db)
        try log.insert(WakeEvent(
            alarmID: nil, alarmLabel: "", scheduledAt: t0, dismissedAt: t0, dismissMethod: .voice,
            snoozeCount: 1, snoozedMinutes: 5, createdAt: t0
        ))
        XCTAssertEqual(try log.events().first?.score, 90)
        try log.rescoreAll(rules: WakeScoreRules(pointsPerSnooze: 30))
        let event = try XCTUnwrap(try log.events().first)
        XCTAssertEqual(event.score, 70)
        XCTAssertFalse(event.isSuccess)
    }

    func testEventsSinceFiltersByDay() throws {
        let db = try AppDatabase.inMemory()
        let log = WakeLogStore(database: db)
        for day in 0..<5 {
            let scheduled = t0.addingTimeInterval(Double(day) * 86_400)
            try log.insert(WakeEvent(alarmID: nil, alarmLabel: "", scheduledAt: scheduled, dismissedAt: scheduled, dismissMethod: .voice, snoozeCount: 0, snoozedMinutes: 0))
        }
        let third = DayKey(t0.addingTimeInterval(2 * 86_400))
        XCTAssertEqual(try log.events(since: third).count, 3)
        XCTAssertEqual(try log.events().count, 5)
    }

    // MARK: Backup

    func testBackupRestoreReplacesEverything() throws {
        let source = try AppDatabase.inMemory()
        var settings = AppSettings()
        settings.butlerName = ButlerName(formal: "Barrington", familiar: "Barry")
        try source.saveSettings(settings)
        try AlarmStore(database: source).save(Alarm(id: "A1", label: "Work", createdAt: t0), at: t0)
        try WakeLogStore(database: source).insert(WakeEvent(
            id: "E1", alarmID: "A1", alarmLabel: "Work", scheduledAt: t0, dismissedAt: t0, dismissMethod: .voice,
            snoozeCount: 0, snoozedMinutes: 0, createdAt: t0
        ))
        try RecommendationStore(database: source).save(Recommendation(id: "R1", kind: .keepSettings, alarmID: "A1", createdAt: t0))
        let payload = try BackupStore(database: source).exportPayload(appVersion: "1.0", at: t0)
        let fileData = try payload.encoded()

        let target = try AppDatabase.inMemory()
        try AlarmStore(database: target).save(Alarm(id: "OLD", createdAt: t0))
        var targetSettings = AppSettings()
        targetSettings.autoBackupEnabled = true
        try target.saveSettings(targetSettings)

        try BackupStore(database: target).replaceAll(with: try BackupPayload.decode(fileData))
        XCTAssertEqual(try AlarmStore(database: target).all().map(\.id), ["A1"])
        XCTAssertEqual(try WakeLogStore(database: target).events().map(\.id), ["E1"])
        XCTAssertEqual(try RecommendationStore(database: target).all().map(\.id), ["R1"])
        let restored = target.loadSettings()
        XCTAssertEqual(restored.butlerName.formal, "Barrington")
        XCTAssertTrue(restored.hasCompletedOnboarding)
        XCTAssertTrue(restored.autoBackupEnabled, "this iPhone's auto-backup choice is kept")
    }

    func testRestoreClearsLinksToMissingAlarms() throws {
        let db = try AppDatabase.inMemory()
        let event = WakeEvent(
            id: "E1", alarmID: "GONE", alarmLabel: "Old", scheduledAt: t0, dismissedAt: t0, dismissMethod: .voice,
            snoozeCount: 0, snoozedMinutes: 0, createdAt: t0
        )
        let payload = BackupPayload(createdAt: t0, appVersion: "1.0", settings: AppSettings(), alarms: [], wakeEvents: [event], recommendations: [])
        try BackupStore(database: db).replaceAll(with: payload)
        XCTAssertNil(try WakeLogStore(database: db).events().first?.alarmID)
    }

    // MARK: Occurrences (Phase 1b)

    func testStopWritesTheWakeLogOnceWithInferredSnoozes() throws {
        let db = try AppDatabase.inMemory()
        try AlarmStore(database: db).save(Alarm(id: "A1", label: "Work", snoozeMinutes: 5, createdAt: t0), at: t0)
        let store = OccurrenceStore(database: db)
        try store.insertIfNew(AlarmOccurrence(id: "R1", alarmID: "A1", scheduledAt: t0, snoozeMinutes: 5, createdAt: t0))
        try store.insertIfNew(AlarmOccurrence(id: "R1", alarmID: "A1", scheduledAt: t0, snoozeMinutes: 5, snoozeCount: 9, createdAt: t0))
        try store.addSnooze(id: "R1")
        // Stopped 11 minutes after the ring: two 5-minute snoozes, although one tap was reported.
        let event = try XCTUnwrap(try store.finish(id: "R1", stoppedAt: t0.addingTimeInterval(11 * 60), method: .system, rules: .default))
        XCTAssertEqual(event.snoozeCount, 2)
        XCTAssertEqual(event.snoozedMinutes, 10)
        XCTAssertEqual(event.alarmLabel, "Work")
        XCTAssertEqual(event.score, 44) // 100 − (11 − 2) × 4 − 2 × 10
        XCTAssertNil(try store.finish(id: "R1", stoppedAt: t0, method: .system, rules: .default))
        XCTAssertEqual(try WakeLogStore(database: db).count(), 1)
        XCTAssertEqual(try store.occurrence(id: "R1")?.status, .finished)
        XCTAssertTrue(try store.scheduled().isEmpty)
    }

    func testMissedRingScoresZero() throws {
        let db = try AppDatabase.inMemory()
        let store = OccurrenceStore(database: db)
        try store.insertIfNew(AlarmOccurrence(id: "R2", alarmID: "GONE", scheduledAt: t0, snoozeMinutes: 5, createdAt: t0))
        let event = try XCTUnwrap(try store.finish(id: "R2", stoppedAt: nil, method: .system, rules: .default))
        XCTAssertEqual(event.dismissMethod, .missed)
        XCTAssertEqual(event.score, 0)
        XCTAssertNil(event.alarmID)
        XCTAssertEqual(try store.occurrence(id: "R2")?.status, .missed)
    }
}
