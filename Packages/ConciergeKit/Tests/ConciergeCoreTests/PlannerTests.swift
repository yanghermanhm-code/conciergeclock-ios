@testable import ConciergeCore
import XCTest

final class PlannerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // Friday 27 Nov 2026, 08:00.
    private var now: Date { date(2026, 11, 27, 8, 0) }

    func testTwoRingsAheadForRepeatingAlarms() {
        let alarm = Alarm(id: "A", hour: 7, minute: 0, repeatDays: Weekdays.workWeek)
        let rings = AlarmPlanner.plan(alarms: [alarm], after: now, calendar: calendar)
        XCTAssertEqual(rings.map(\.fireDate), [date(2026, 11, 30, 7, 0), date(2026, 12, 1, 7, 0)])
    }

    func testOneOffAlarmRingsOnceAndDisabledNever() {
        let once = Alarm(id: "O", hour: 9, minute: 30, repeatDays: [])
        let off = Alarm(id: "X", hour: 9, minute: 30, isEnabled: false)
        let rings = AlarmPlanner.plan(alarms: [once, off], after: now, calendar: calendar)
        XCTAssertEqual(rings.map(\.alarmID), ["O"])
        XCTAssertEqual(rings.first?.fireDate, date(2026, 11, 27, 9, 30))
    }

    func testDaysOffAreSkippedOnlyWhenTheAlarmAsks() {
        let monday = DayKey(date(2026, 11, 30, 12, 0), calendar: calendar)
        var alarm = Alarm(id: "A", hour: 7, minute: 0, repeatDays: Weekdays.workWeek)
        let skipping = AlarmPlanner.plan(alarms: [alarm], after: now, calendar: calendar) { $0 == monday }
        XCTAssertEqual(skipping.map(\.fireDate), [date(2026, 12, 1, 7, 0), date(2026, 12, 2, 7, 0)])
        alarm.skipOnDaysOff = false
        let ringing = AlarmPlanner.plan(alarms: [alarm], after: now, calendar: calendar) { $0 == monday }
        XCTAssertEqual(ringing.first?.fireDate, date(2026, 11, 30, 7, 0))
    }

    func testOccurrenceIDsAreStableAndDistinct() {
        let fire = date(2026, 11, 30, 7, 0)
        XCTAssertEqual(AlarmPlanner.occurrenceID(alarmID: "A", fireDate: fire), AlarmPlanner.occurrenceID(alarmID: "A", fireDate: fire))
        XCTAssertNotEqual(AlarmPlanner.occurrenceID(alarmID: "A", fireDate: fire), AlarmPlanner.occurrenceID(alarmID: "B", fireDate: fire))
        XCTAssertNotEqual(AlarmPlanner.occurrenceID(alarmID: "A", fireDate: fire), AlarmPlanner.occurrenceID(alarmID: "A", fireDate: fire.addingTimeInterval(60)))
    }

    func testInferredSnoozes() {
        let t0 = date(2026, 11, 30, 7, 0)
        XCTAssertEqual(AlarmPlanner.inferredSnoozes(scheduledAt: t0, stoppedAt: t0.addingTimeInterval(40), snoozeMinutes: 5), 0)
        XCTAssertEqual(AlarmPlanner.inferredSnoozes(scheduledAt: t0, stoppedAt: t0.addingTimeInterval(5 * 60 + 20), snoozeMinutes: 5), 1)
        XCTAssertEqual(AlarmPlanner.inferredSnoozes(scheduledAt: t0, stoppedAt: t0.addingTimeInterval(31 * 60), snoozeMinutes: 10), 3)
        XCTAssertEqual(AlarmPlanner.inferredSnoozes(scheduledAt: t0, stoppedAt: t0.addingTimeInterval(-60), snoozeMinutes: 5), 0)
    }

    func testDayOffRules() {
        let keywords = AppSettings.defaultDayOffKeywords
        XCTAssertTrue(DayOffRules.isDayOff([AllDayItem(title: "Family vacation 🌴", calendarTitle: "Home")], keywords: keywords))
        XCTAssertTrue(DayOffRules.isDayOff([AllDayItem(title: "Boxing Day", calendarTitle: "Holidays in Canada")], keywords: keywords))
        XCTAssertTrue(DayOffRules.isDayOff([AllDayItem(title: "Noël", calendarTitle: "Jours fériés")], keywords: keywords))
        XCTAssertTrue(DayOffRules.isDayOff([AllDayItem(title: "ooo – conference", calendarTitle: "Work")], keywords: keywords))
        XCTAssertFalse(DayOffRules.isDayOff([AllDayItem(title: "Mum's birthday", calendarTitle: "Birthdays")], keywords: keywords))
        XCTAssertFalse(DayOffRules.isDayOff([AllDayItem(title: "Crypto meetup", calendarTitle: "Work")], keywords: keywords))
        XCTAssertTrue(DayOffRules.isDayOff([AllDayItem(title: "Out-of-office", calendarTitle: "Work")], keywords: keywords))
        XCTAssertFalse(DayOffRules.isDayOff([], keywords: keywords))
    }

    func testSnapshotRoundTrip() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let snapshot = NextAlarmSnapshot(fireDate: now, label: "Gym", enabledAlarmCount: 2, languageCode: "fr", updatedAt: now)
        try snapshot.write(to: folder)
        XCTAssertEqual(NextAlarmSnapshot.read(from: folder), snapshot)
    }

    func testExactDateAlarmRingsOnThatDayOnlyAndBeyondTheHorizon() {
        let christmas = DayKey(date(2026, 12, 25, 12, 0), calendar: calendar)
        let alarm = Alarm(id: "X", hour: 6, minute: 45, repeatDays: [], date: christmas)
        XCTAssertTrue(alarm.isDated)
        XCTAssertEqual(alarm.nextFireDate(after: now, calendar: calendar), date(2026, 12, 25, 6, 45))
        XCTAssertNil(alarm.nextFireDate(after: date(2026, 12, 25, 7, 0), calendar: calendar))
        // 28 days ahead (beyond the 8-day horizon), and not skipped although Christmas is a day off.
        let rings = AlarmPlanner.plan(alarms: [alarm], after: now, calendar: calendar) { _ in true }
        XCTAssertEqual(rings.map(\.fireDate), [date(2026, 12, 25, 6, 45)])
    }

    func testRepeatingAlarmIgnoresADate() {
        let alarm = Alarm(id: "R", hour: 7, minute: 0, repeatDays: Weekdays.workWeek, date: DayKey(date(2026, 12, 25, 12, 0), calendar: calendar))
        XCTAssertNil(alarm.date)
        XCTAssertFalse(alarm.isDated)
    }

    func testExactDateAlarmForTheCurrentMinuteRingsAtOnce() {
        let today = DayKey(now, calendar: calendar)
        // 08:00:40 with an alarm for today 08:00.
        let at = now.addingTimeInterval(40)
        let alarm = Alarm(id: "N", hour: 8, minute: 0, repeatDays: [], date: today)
        XCTAssertEqual(alarm.nextFireDate(after: at, calendar: calendar), now)
        let rings = AlarmPlanner.plan(alarms: [alarm], after: at, calendar: calendar)
        XCTAssertEqual(rings.first?.fireDate, at.addingTimeInterval(3))
        XCTAssertEqual(rings.first?.id, AlarmPlanner.occurrenceID(alarmID: "N", fireDate: now))
        // A minute later it has passed.
        XCTAssertNil(alarm.nextFireDate(after: now.addingTimeInterval(61), calendar: calendar))
    }
}
