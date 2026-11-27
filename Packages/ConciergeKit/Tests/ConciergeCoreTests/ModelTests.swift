@testable import ConciergeCore
import XCTest

final class ModelTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: Settings

    func testDefaultsMatchTheAgreedProduct() {
        let settings = AppSettings()
        XCTAssertEqual(settings.butlerName.formal, "Charles")
        XCTAssertEqual(settings.butlerName.familiar, "Charlie")
        XCTAssertEqual(settings.voiceAccent, .britishMale)
        XCTAssertEqual(settings.tone, .professional)
        XCTAssertEqual(settings.briefingLanguageCode, "en")
        XCTAssertEqual(settings.defaultSnoozeMinutes, 5)
        XCTAssertTrue(settings.allowMildSwearing)
        XCTAssertEqual(settings.persona().displayName, "Charles")
    }

    func testSettingsDecodingIsForgiving() throws {
        let json = #"{"tone":"unhinged","defaultSnoozeMinutes":999,"voiceAccent":"martian","futureKey":true,"butlerName":{"formal":"  Barrington the Third  ","familiar":""}}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.tone, .unhinged)
        XCTAssertEqual(settings.defaultSnoozeMinutes, 120)
        XCTAssertEqual(settings.voiceAccent, .britishMale)
        XCTAssertEqual(settings.butlerName.formal, "Barrington the Third")
        // A blank familiar name falls back to the formal one.
        XCTAssertEqual(settings.persona().displayName, "Barrington the Third")
    }

    func testSettingsRoundTrip() throws {
        var settings = AppSettings()
        settings.butlerName = ButlerName(formal: "Barrington", familiar: "Barry")
        settings.tone = .moderate
        settings.wakeScoreRules.successThreshold = 70
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(decoded.persona().displayName, "Barry")
    }

    func testAlarmOverridesShapeThePersona() {
        var settings = AppSettings()
        settings.briefingLanguageCode = "fr"
        let alarm = Alarm(snoozeMinutes: 10, toneOverride: .child, accentOverride: .indianFemale, lengthOverride: .full)
        let persona = settings.persona(for: alarm)
        XCTAssertEqual(persona.tone, .child)
        XCTAssertEqual(persona.accent, .indianFemale)
        XCTAssertEqual(persona.length, .full)
        XCTAssertEqual(persona.languageCode, "fr")
        XCTAssertFalse(persona.usesAccent)
        XCTAssertEqual(settings.snoozeMinutes(for: alarm), 10)
        XCTAssertEqual(settings.snoozeMinutes(for: nil), 5)
    }

    func testAccentsCoverEightProfiles() {
        XCTAssertEqual(VoiceAccent.allCases.count, 8)
        XCTAssertEqual(Set(VoiceAccent.allCases.map(\.region)).count, 4)
        XCTAssertEqual(VoiceAccent.allCases.filter { $0.gender == .female }.count, 4)
        XCTAssertTrue(VoiceAccent.southernFemale.isApproximated)
        XCTAssertFalse(VoiceAccent.britishMale.isApproximated)
        XCTAssertEqual(VoiceAccent.britishMale.preferredLocales.first, "en-GB")
    }

    // MARK: Alarms

    func testNextFireDateTodayOrTomorrow() {
        let alarm = Alarm(hour: 7, minute: 30, repeatDays: [])
        // Friday 27 Nov 2026, 06:00 → today 07:30.
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 11, 27, 6, 0), calendar: calendar), date(2026, 11, 27, 7, 30))
        // 08:00 → tomorrow 07:30.
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 11, 27, 8, 0), calendar: calendar), date(2026, 11, 28, 7, 30))
    }

    func testNextFireDateHonoursRepeatDaysAndSkip() {
        var alarm = Alarm(hour: 7, minute: 0, repeatDays: Weekdays.workWeek)
        // Friday 08:00 → Monday 30 Nov.
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 11, 27, 8, 0), calendar: calendar), date(2026, 11, 30, 7, 0))
        alarm.skipDay = DayKey(date(2026, 11, 30, 7, 0), calendar: calendar)
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 11, 27, 8, 0), calendar: calendar), date(2026, 12, 1, 7, 0))
        alarm.isEnabled = false
        XCTAssertNil(alarm.nextFireDate(after: date(2026, 11, 27, 8, 0), calendar: calendar))
    }

    func testAlarmClampsInput() {
        let alarm = Alarm(hour: 31, minute: -4, repeatDays: [0, 3, 9], snoozeMinutes: 0, rampUpSeconds: 9_999)
        XCTAssertEqual(alarm.hour, 23)
        XCTAssertEqual(alarm.minute, 0)
        XCTAssertEqual(alarm.repeatDays, [3])
        XCTAssertEqual(alarm.snoozeMinutes, 1)
        XCTAssertEqual(alarm.rampUpSeconds, 300)
    }
}
