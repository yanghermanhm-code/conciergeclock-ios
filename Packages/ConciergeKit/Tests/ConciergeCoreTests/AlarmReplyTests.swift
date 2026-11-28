@testable import ConciergeCore
import XCTest

final class AlarmReplyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: hour, minute: minute))!
    }

    private func parse(_ text: String) -> AlarmReply {
        AlarmReplyParser.parse(text, defaultSnoozeMinutes: 5)
    }

    // MARK: Rules

    func testDismissPhrases() {
        for text in ["Dismiss", "Stop the alarm", "OK, I'm up", "I'm awake", "Yes, I will go", "Got it", "arrête", "Ya estoy despierto", "我醒了", "בסדר"] {
            XCTAssertEqual(parse(text), .dismiss, text)
        }
    }

    func testRemindPhrases() {
        XCTAssertEqual(parse("Snooze"), .remindIn(minutes: 5))
        XCTAssertEqual(parse("Remind me again"), .remindIn(minutes: 5))
        XCTAssertEqual(parse("Remind me in 10 minutes"), .remindIn(minutes: 10))
        XCTAssertEqual(parse("Five more minutes"), .remindIn(minutes: 5))
        XCTAssertEqual(parse("Give me twenty minutes"), .remindIn(minutes: 20))
        XCTAssertEqual(parse("Half an hour"), .remindIn(minutes: 30))
        XCTAssertEqual(parse("Remind me in an hour"), .remindIn(minutes: 60))
        XCTAssertEqual(parse("Remind me in a minute"), .remindIn(minutes: 1))
        XCTAssertEqual(parse("Rappelle-moi dans 15 minutes"), .remindIn(minutes: 15))
        XCTAssertEqual(parse("10分钟后提醒我"), .remindIn(minutes: 10))
        XCTAssertEqual(parse("Remind me in 5 hours"), .remindIn(minutes: Snooze.minuteRange.upperBound))
    }

    func testRemindAtClockTimes() {
        XCTAssertEqual(parse("Remind me at 7:15"), .remindAt(hour: 7, minute: 15))
        XCTAssertEqual(parse("At quarter past seven"), .remindAt(hour: 7, minute: 15))
        XCTAssertEqual(parse("Wake me at quarter to eight"), .remindAt(hour: 7, minute: 45))
        XCTAssertEqual(parse("Remind me at seven thirty"), .remindAt(hour: 7, minute: 30))
        XCTAssertEqual(parse("Remind me at 8"), .remindAt(hour: 8, minute: 0))
        XCTAssertEqual(parse("Recuérdame a las 7"), .remindAt(hour: 7, minute: 0))
        XCTAssertEqual(parse("Rappelle-moi à 7 heures"), .remindAt(hour: 7, minute: 0))
        XCTAssertEqual(parse("Ingatkan pukul 6"), .remindAt(hour: 6, minute: 0))
    }

    func testRepeatAndUnknown() {
        XCTAssertEqual(parse("Say that again"), .repeatPrompt)
        XCTAssertEqual(parse("Pardon?"), .repeatPrompt)
        XCTAssertEqual(parse("Purple elephants"), .unknown)
        XCTAssertEqual(parse("   "), .unknown)
    }

    // MARK: Offline AI

    private struct FakeModel: TextGenerating {
        let reply: String
        var modelName: String { "Fake" }
        func generate(system: String, prompt: String, jsonSchema: String?, maxTokens: Int, temperature: Double) async throws -> String { reply }
    }

    func testModelReplyIsParsedTolerantly() {
        XCTAssertEqual(ModelAlarmReplyInterpreter.parse(#"Sure: {"action":"remind_in","minutes":12}"#, defaultSnoozeMinutes: 5), .remindIn(minutes: 12))
        XCTAssertEqual(ModelAlarmReplyInterpreter.parse(#"{"action":"remind_in"}"#, defaultSnoozeMinutes: 7), .remindIn(minutes: 7))
        XCTAssertEqual(ModelAlarmReplyInterpreter.parse(#"{"action":"remind_at","time":"06:45"}"#, defaultSnoozeMinutes: 5), .remindAt(hour: 6, minute: 45))
        XCTAssertNil(ModelAlarmReplyInterpreter.parse(#"{"action":"remind_at","time":"25:00"}"#, defaultSnoozeMinutes: 5))
        XCTAssertEqual(ModelAlarmReplyInterpreter.parse(#"{"action":"dismiss"}"#, defaultSnoozeMinutes: 5), .dismiss)
        XCTAssertEqual(ModelAlarmReplyInterpreter.parse(#"{"action":"something"}"#, defaultSnoozeMinutes: 5), .unknown)
        XCTAssertNil(ModelAlarmReplyInterpreter.parse("no json here", defaultSnoozeMinutes: 5))
    }

    func testModelInterpretsWhatRulesCannot() async {
        let model = FakeModel(reply: #"{"action":"dismiss"}"#)
        let reply = await ModelAlarmReplyInterpreter.interpret("Alright alright, I'm getting out of bed", using: model, defaultSnoozeMinutes: 5)
        XCTAssertEqual(reply, .dismiss)
    }

    // MARK: Reminder dates

    func testReminderDates() {
        let now = date(7, 0)
        XCTAssertEqual(reminderDate(for: .remindIn(minutes: 10), now: now, calendar: calendar), date(7, 10))
        XCTAssertEqual(reminderDate(for: .remindAt(hour: 7, minute: 30), now: now, calendar: calendar), date(7, 30))
        // "At 6" said at 7:00 means 18:00 today.
        XCTAssertEqual(reminderDate(for: .remindAt(hour: 6, minute: 0), now: now, calendar: calendar), date(18, 0))
        // "At 18:00" said at 19:00 means tomorrow.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date(18, 0))
        XCTAssertEqual(reminderDate(for: .remindAt(hour: 18, minute: 0), now: date(19, 0), calendar: calendar), tomorrow)
        XCTAssertNil(reminderDate(for: .dismiss, now: now, calendar: calendar))
    }

    // MARK: What the butler says

    private let phrases = PhraseBook(languageCode: "en", phrases: [
        "brief.professional.greeting.morning": "Good morning.",
        "brief.professional.time": "It is %@.",
        "brief.professional.next": "Your next engagement is %1$@, at %2$@, in %3$@.",
        "brief.professional.important": "I would treat this one as important.",
        "brief.professional.reminderItem": "You asked to be reminded: %@.",
        "brief.professional.overdue": "%@ is, I regret to say, overdue.",
        "brief.professional.noEvents": "Your diary is clear.",
        "brief.professional.alarm.this": "This is your %@ alarm.",
        "brief.professional.alarm.thisNoLabel": "This is your alarm.",
        "brief.professional.alarm.ask": "Shall I dismiss the alarm, or remind you again in %d minutes?",
        "brief.professional.alarm.respondHint": "Press Respond to give me your answer.",
        "brief.professional.ack.dismiss": "Very good. The alarm is dismissed.",
        "brief.professional.ack.remind": "Very well. I shall remind you again at %@.",
        "brief.professional.ack.unclear": "I beg your pardon? Dismiss, or remind you in %d minutes?",
        "brief.professional.ack.noAnswer": "No reply, I see. I shall return at %@.",
        "brief.summary.at": "at %@",
        "brief.summary.for": "for %@",
        "brief.summary.with": "with %d others",
        "brief.private": "a private event",
    ])

    private var builder: BriefingBuilder {
        BriefingBuilder(persona: Persona(tone: .professional, length: .quick, languageCode: "en"), phrases: phrases, calendar: calendar)
    }

    func testAnnouncementNamesTheAlarmAndTheNextItemThenAsks() {
        let gym = BriefingItem(id: "g", kind: .event, title: "Gym", date: date(6, 0), endDate: date(6, 45))
        let dentist = BriefingItem(id: "d", kind: .event, title: "Dentist", date: date(9, 15), endDate: date(10, 0))
        let rent = BriefingItem(id: "p", kind: .reminder, title: "Pay rent", date: nil, isOverdue: true)
        let items = [
            RankedItem(item: gym, importance: .normal, source: .rules),
            RankedItem(item: rent, importance: .high, source: .rules),
            RankedItem(item: dentist, importance: .high, source: .rules),
        ]
        let text = builder.alarmAnnouncement(alarmLabel: "Work", items: items, now: date(7, 0), snoozeMinutes: 5).text
        XCTAssertTrue(text.hasPrefix("Good morning. It is 7:00"), text)
        XCTAssertTrue(text.contains("This is your Work alarm."), text)
        // The finished gym session is skipped; the dentist comes next.
        XCTAssertTrue(text.contains("Your next engagement is Dentist, at 9:15"), text)
        XCTAssertFalse(text.contains("Gym"), text)
        XCTAssertTrue(text.contains("I would treat this one as important."), text)
        XCTAssertTrue(text.hasSuffix("Shall I dismiss the alarm, or remind you again in 5 minutes?"), text)
        XCTAssertFalse(text.contains("Press Respond"), text)

        let recorded = builder.alarmAnnouncement(alarmLabel: "", items: [], now: date(7, 0), snoozeMinutes: 10, forSoundFile: true).text
        XCTAssertTrue(recorded.contains("This is your alarm."), recorded)
        XCTAssertTrue(recorded.contains("Your diary is clear."), recorded)
        XCTAssertTrue(recorded.hasSuffix("remind you again in 10 minutes? Press Respond to give me your answer."), recorded)
    }

    func testAnnouncementFallsBackToTheMostImportantReminder() {
        let rent = BriefingItem(id: "p", kind: .reminder, title: "Pay rent", date: nil, isOverdue: true)
        let milk = BriefingItem(id: "m", kind: .reminder, title: "Buy milk", date: nil)
        let items = [RankedItem(item: milk, importance: .normal, source: .rules), RankedItem(item: rent, importance: .high, source: .rules)]
        let text = builder.alarmAnnouncement(alarmLabel: "", items: items, now: date(7, 0), snoozeMinutes: 5).text
        XCTAssertTrue(text.contains("Pay rent is, I regret to say, overdue."), text)
        XCTAssertFalse(text.contains("Buy milk"), text)
    }

    func testAcknowledgements() {
        XCTAssertEqual(builder.acknowledgement(.dismiss, remindAt: nil, snoozeMinutes: 5), "Very good. The alarm is dismissed.")
        XCTAssertTrue(builder.acknowledgement(.remindIn(minutes: 10), remindAt: date(7, 10), snoozeMinutes: 5).hasPrefix("Very well. I shall remind you again at 7:10"))
        XCTAssertEqual(builder.acknowledgement(.unknown, remindAt: nil, snoozeMinutes: 5), "I beg your pardon? Dismiss, or remind you in 5 minutes?")
        XCTAssertTrue(builder.noAnswer(remindAt: date(7, 5)).hasPrefix("No reply, I see. I shall return at 7:05"))
    }
}
