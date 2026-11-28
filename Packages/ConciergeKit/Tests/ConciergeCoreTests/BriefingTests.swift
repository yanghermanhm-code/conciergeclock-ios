@testable import ConciergeCore
import XCTest

final class BriefingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: hour, minute: minute))!
    }

    // MARK: Importance rules

    func testRulesFlagWhatMatters() {
        let interview = BriefingItem(id: "1", kind: .event, title: "Job interview with Acme", date: date(9, 30), endDate: date(10, 30))
        let lunch = BriefingItem(id: "2", kind: .event, title: "Lunch", date: date(12, 0), endDate: date(13, 0))
        let crypto = BriefingItem(id: "3", kind: .event, title: "Crypto meetup", date: date(18, 0), endDate: date(19, 0))
        let overdue = BriefingItem(id: "4", kind: .reminder, title: "Pay rent", date: nil, isOverdue: true)
        let flagged = BriefingItem(id: "5", kind: .reminder, title: "Call Sam", date: date(11, 0), priority: 1)
        let allDay = BriefingItem(id: "6", kind: .event, title: "Sam's birthday", date: date(0, 0), isAllDay: true)
        XCTAssertEqual(ImportanceRules.judge(interview), .high)
        XCTAssertEqual(ImportanceRules.judge(lunch), .normal)
        XCTAssertEqual(ImportanceRules.judge(crypto), .normal)
        XCTAssertEqual(ImportanceRules.judge(overdue), .high)
        XCTAssertEqual(ImportanceRules.judge(flagged), .high)
        XCTAssertEqual(ImportanceRules.judge(allDay), .low)
    }

    // MARK: Offline AI ranking

    private struct FakeModel: TextGenerating {
        let reply: String
        var modelName: String { "Fake" }
        func generate(system: String, prompt: String, jsonSchema: String?, maxTokens: Int, temperature: Double) async throws -> String { reply }
    }

    func testModelReplyIsParsedTolerantly() {
        XCTAssertEqual(ModelImportanceRanker.parse(#"Sure! {"items":[{"id":"0","important":true},{"id":1,"important":false}]} Done."#), [0: true, 1: false])
        XCTAssertNil(ModelImportanceRanker.parse("no json here"))
    }

    func testModelOverridesRulesButNeverInventsItems() async {
        let lunch = BriefingItem(id: "a", kind: .event, title: "Lunch with the CEO", date: date(12, 0), endDate: date(13, 0))
        let gym = BriefingItem(id: "b", kind: .event, title: "Dentist", date: date(15, 0), endDate: date(16, 0))
        let model = FakeModel(reply: #"{"items":[{"id":"0","important":true},{"id":"1","important":false},{"id":"7","important":true}]}"#)
        let ranked = await ModelImportanceRanker.rank([lunch, gym], using: model, now: date(7, 0))
        XCTAssertEqual(ranked?.map(\.item.id), ["a", "b"])
        XCTAssertEqual(ranked?.map(\.importance), [.high, .normal])
        XCTAssertEqual(ranked?.first?.source, .offlineAI)
        let broken = await ModelImportanceRanker.rank([lunch], using: FakeModel(reply: "I can't"), now: date(7, 0))
        XCTAssertNil(broken)
    }

    func testPromptCarriesFactsButNotTooMuch() {
        let item = BriefingItem(id: "x", kind: .event, title: "Flight \"AC 101\"", date: date(9, 15), endDate: date(11, 0),
                                location: "YYZ", attendeeCount: 2, calendarTitle: "Travel", notesSnippet: String(repeating: "n", count: 400))
        let prompt = ModelImportanceRanker.prompt(for: [item], now: date(7, 0), calendar: calendar)
        XCTAssertTrue(prompt.contains("id=0 event title=\"Flight 'AC 101'\" time=Mon 2026-11-30 09:15 minutes=105 place=\"YYZ\" others=2"))
        XCTAssertLessThan(prompt.count, 500)
    }

    // MARK: Script

    private let phrases = PhraseBook(languageCode: "en", phrases: [
        "brief.professional.greeting.morning": "Good morning.",
        "brief.professional.time": "It is %@.",
        "brief.professional.next": "Your next engagement is %1$@, at %2$@, in %3$@.",
        "brief.professional.important": "I would treat this one as important.",
        "brief.professional.more": "Further engagements today: %d.",
        "brief.professional.item": "%1$@, at %2$@.",
        "brief.professional.reminders": "Matters awaiting your attention: %d.",
        "brief.professional.reminderItem": "You asked to be reminded: %@.",
        "brief.professional.overdue": "%@ is, I regret to say, overdue.",
        "brief.professional.noEvents": "Your diary is clear.",
        "brief.professional.closing.alarm": "Shall I return in %d minutes, or will you be rising?",
        "brief.professional.closing.onDemand": "That will be all for now.",
        "brief.unhinged.greeting.morning": "Oh, you're alive.",
        "brief.unhinged.time": "It is %@.",
        "brief.unhinged.noEvents": "Empty.",
        "brief.unhinged.closing.onDemand": "Go.",
        "brief.unhinged.swear.1": "Swear one.",
        "brief.unhinged.swear.2": "Swear two.",
        "brief.summary.at": "at %@",
        "brief.summary.for": "for %@",
        "brief.summary.with": "with %d others",
        "brief.private": "a private event",
    ])

    private var items: [RankedItem] {
        let dentist = BriefingItem(id: "d", kind: .event, title: "Dentist", date: date(9, 15), endDate: date(10, 0), location: "Dr. Smith")
        let standup = BriefingItem(id: "s", kind: .event, title: "Stand-up", date: date(10, 30), endDate: date(10, 45))
        let review = BriefingItem(id: "r", kind: .event, title: "Design review", date: date(14, 0), endDate: date(15, 0))
        let rent = BriefingItem(id: "p", kind: .reminder, title: "Pay rent", date: nil, isOverdue: true)
        return [
            RankedItem(item: standup, importance: .normal, source: .rules),
            RankedItem(item: dentist, importance: .high, source: .rules),
            RankedItem(item: review, importance: .high, source: .rules),
            RankedItem(item: rent, importance: .high, source: .rules),
        ]
    }

    func testQuickProfessionalAlarmBriefing() {
        let persona = Persona(tone: .professional, length: .quick, languageCode: "en")
        let briefing = BriefingBuilder(persona: persona, phrases: phrases, calendar: calendar)
            .build(items: items, now: date(7, 0), trigger: .alarm(snoozeMinutes: 5))
        let text = briefing.text
        XCTAssertTrue(text.hasPrefix("Good morning. It is 7:00"), text)
        XCTAssertTrue(text.contains("Your next engagement is Dentist, at 9:15"), text)
        XCTAssertTrue(text.contains("in 2 hours, 15 minutes."), text)
        XCTAssertTrue(text.contains("At Dr. Smith, for 45 minutes."), text)
        XCTAssertTrue(text.contains("I would treat this one as important."), text)
        XCTAssertTrue(text.contains("Further engagements today: 2."), text)
        XCTAssertTrue(text.contains("Matters awaiting your attention: 1."), text)
        XCTAssertTrue(text.hasSuffix("Shall I return in 5 minutes, or will you be rising?"), text)
    }

    func testStandardListsMostImportantInTimeOrder() {
        let persona = Persona(tone: .professional, length: .standard, languageCode: "en")
        let briefing = BriefingBuilder(persona: persona, phrases: phrases, calendar: calendar)
            .build(items: items, now: date(7, 0), trigger: .onDemand)
        let itemLines = briefing.lines.filter { $0.kind == .item }.map(\.text)
        // Next is the dentist; of the two others both fit (limit 2), in time order.
        XCTAssertEqual(itemLines.count, 2)
        XCTAssertTrue(itemLines[0].hasPrefix("Stand-up, at 10:30"), itemLines[0])
        XCTAssertTrue(itemLines[1].hasPrefix("Design review, at 2:00"), itemLines[1])
        XCTAssertTrue(itemLines[1].hasSuffix("I would treat this one as important."))
        XCTAssertTrue(briefing.text.contains("Pay rent is, I regret to say, overdue."))
        XCTAssertEqual(briefing.lines.last?.text, "That will be all for now.")
    }

    func testPrivateModeHidesTitlesAndPlaces() {
        let persona = Persona(tone: .professional, length: .quick, languageCode: "en")
        let text = BriefingBuilder(persona: persona, phrases: phrases, calendar: calendar, speakTitles: false)
            .build(items: items, now: date(7, 0), trigger: .onDemand).text
        XCTAssertFalse(text.contains("Dentist"))
        XCTAssertFalse(text.contains("Smith"))
        XCTAssertTrue(text.contains("Your next engagement is a private event"))
    }

    func testUnhingedSwearsOnlyWhenAllowedAndEmptyDay() {
        var persona = Persona(tone: .unhinged, length: .quick, languageCode: "en", allowMildSwearing: true)
        let builder = BriefingBuilder(persona: persona, phrases: phrases, calendar: calendar)
        XCTAssertTrue(builder.build(items: [], now: date(7, 0), trigger: .onDemand, variation: 0).text.contains("Swear one."))
        XCTAssertTrue(builder.build(items: [], now: date(7, 0), trigger: .onDemand, variation: 1).text.contains("Swear two."))
        persona.allowMildSwearing = false
        let clean = BriefingBuilder(persona: persona, phrases: phrases, calendar: calendar).build(items: [], now: date(7, 0), trigger: .onDemand)
        XCTAssertFalse(clean.text.contains("Swear"))
        XCTAssertTrue(clean.text.contains("Empty."))
    }

    func testRegionalFlourishOnlyForNorthAmericanEnglishOutsideProfessional() {
        let southern = Persona(accent: .southernFemale, tone: .unhinged, languageCode: "en", allowMildSwearing: false)
        XCTAssertEqual(BriefingBuilder(persona: southern, phrases: phrases, calendar: calendar).regionalFlourish(), "Y'all have a good one now.")
        let formal = Persona(accent: .canadianMale, tone: .professional, languageCode: "en")
        XCTAssertNil(BriefingBuilder(persona: formal, phrases: phrases, calendar: calendar).regionalFlourish())
        let french = Persona(accent: .canadianMale, tone: .moderate, languageCode: "fr")
        XCTAssertNil(BriefingBuilder(persona: french, phrases: phrases, calendar: calendar).regionalFlourish())
    }

    func testProsodyPerTone() {
        XCTAssertLessThan(Prosody.forPersona(Persona(tone: .child)).rate, Prosody.forPersona(Persona(tone: .unhinged)).rate)
        XCTAssertLessThan(Prosody.forPersona(Persona(accent: .southernMale, tone: .moderate)).rate, 0.5)
    }
}
