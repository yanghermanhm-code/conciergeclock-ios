import Foundation

/// What prompted a briefing.
public enum BriefingTrigger: Sendable, Hashable {
    /// "Brief Me Now" or "Preview my briefing".
    case onDemand
    /// A ringing alarm (Phase 3): ends with the snooze question.
    case alarm(snoozeMinutes: Int)
}

/// One spoken sentence.
public struct BriefingLine: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable {
        case greeting, time, next, important, item, count, reminder, flourish, closing
    }

    public var id: Int
    public var kind: Kind
    public var text: String

    public init(id: Int, kind: Kind, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}

/// A finished script, in one language, ready to speak.
public struct Briefing: Sendable, Hashable {
    public var languageCode: String
    public var lines: [BriefingLine]

    public init(languageCode: String, lines: [BriefingLine]) {
        self.languageCode = languageCode
        self.lines = lines
    }

    public var text: String { lines.map(\.text).joined(separator: " ") }
}

/// Looks up the butler's phrases ("brief.*" keys) in one language.
public struct PhraseBook: Sendable {
    public let languageCode: String
    private let lookup: @Sendable (String) -> String?

    /// Phrases from ConciergeCore's own resources (`Resources/<lang>.lproj/Localizable.strings`),
    /// falling back to English.
    public init(languageCode: String) {
        self.languageCode = languageCode
        // Paths (Sendable) are captured, not bundles; Bundle(path:) returns its cached instance.
        let path = Bundle.module.path(forResource: languageCode, ofType: "lproj")
        let englishPath = Bundle.module.path(forResource: "en", ofType: "lproj")
        self.lookup = { key in
            let missing = "\u{1}"
            if let path, let value = Bundle(path: path)?.localizedString(forKey: key, value: missing, table: nil), value != missing {
                return value
            }
            if let englishPath, let value = Bundle(path: englishPath)?.localizedString(forKey: key, value: missing, table: nil), value != missing {
                return value
            }
            return nil
        }
    }

    /// A phrase book from a dictionary (tests).
    public init(languageCode: String, phrases: [String: String]) {
        self.languageCode = languageCode
        self.lookup = { phrases[$0] }
    }

    public subscript(_ key: String) -> String {
        lookup(key) ?? key
    }

    public func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: self[key], locale: Locale(identifier: languageCode), arguments: arguments)
    }

}

/// Builds what the butler says, deterministically, from ranked items and the persona.
///
/// Order: greeting · the time · the next event (with its summary, start time, how long until
/// it starts and whether it looks important) · per length, more events and due reminders ·
/// a closing line (the snooze question at an alarm). Times and counts come from the calendar;
/// the wording from the phrase book of the persona's language and tone.
public struct BriefingBuilder: Sendable {
    public var persona: Persona
    public var phrases: PhraseBook
    public var calendar: Calendar
    /// Read event titles aloud (Settings › Your Concierge); off = "a private event".
    public var speakTitles: Bool

    public init(persona: Persona, phrases: PhraseBook? = nil, calendar: Calendar = .current, speakTitles: Bool = true) {
        self.persona = persona
        self.phrases = phrases ?? PhraseBook(languageCode: persona.languageCode)
        self.calendar = calendar
        self.speakTitles = speakTitles
    }

    private var locale: Locale { Locale(identifier: persona.languageCode) }
    private var tone: String { persona.tone.rawValue }

    public func build(items: [RankedItem], now: Date, trigger: BriefingTrigger, variation: Int = 0) -> Briefing {
        var lines: [BriefingLine] = []
        func add(_ kind: BriefingLine.Kind, _ text: String) {
            guard let text = text.nonBlank else { return }
            lines.append(BriefingLine(id: lines.count, kind: kind, text: text))
        }

        add(.greeting, greeting(now: now))
        add(.time, phrases.format("brief.\(tone).time", time(now)))

        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let events = items
            .filter { $0.item.kind == .event && !$0.item.isAllDay }
            .filter { ($0.item.endDate ?? $0.item.date ?? now) > now && ($0.item.date ?? now) < endOfDay }
            .sorted { ($0.item.date ?? now) < ($1.item.date ?? now) }
        let reminders = items
            .filter { $0.item.kind == .reminder }
            .sorted { ($0.importance, $1.item.date ?? Date.distantFuture) > ($1.importance, $0.item.date ?? Date.distantFuture) }

        if let next = events.first {
            add(.next, nextLine(next, now: now))
            if next.importance == .high { add(.important, phrases["brief.\(tone).important"]) }
            let rest = Array(events.dropFirst())
            let limit = persona.length.itemLimit - 1
            if limit > 0, !rest.isEmpty {
                // The most important first, then spoken in time order.
                let chosen = rest.enumerated()
                    .sorted { ($0.element.importance, -$0.offset) > ($1.element.importance, -$1.offset) }
                    .prefix(limit)
                    .map(\.element)
                    .sorted { ($0.item.date ?? now) < ($1.item.date ?? now) }
                for event in chosen {
                    add(.item, itemLine(event))
                }
                let unspoken = rest.count - chosen.count
                if unspoken > 0 { add(.count, phrases.format("brief.\(tone).more", unspoken)) }
            } else if !rest.isEmpty {
                add(.count, phrases.format("brief.\(tone).more", rest.count))
            }
        } else {
            add(.next, phrases["brief.\(tone).noEvents"])
        }

        if !reminders.isEmpty {
            switch persona.length {
            case .quick:
                add(.reminder, phrases.format("brief.\(tone).reminders", reminders.count))
            case .standard, .full:
                let limit = persona.length == .standard ? 3 : persona.length.itemLimit
                for reminder in reminders.prefix(limit) {
                    let key = reminder.item.isOverdue ? "brief.\(tone).overdue" : "brief.\(tone).reminderItem"
                    add(.reminder, phrases.format(key, title(reminder.item)))
                }
                if reminders.count > limit {
                    add(.count, phrases.format("brief.\(tone).reminders", reminders.count))
                }
            }
        }

        if persona.tone == .unhinged, persona.allowMildSwearing {
            add(.flourish, phrases["brief.unhinged.swear.\(variation % 2 + 1)"])
        }
        if let flourish = regionalFlourish() { add(.flourish, flourish) }

        switch trigger {
        case .onDemand:
            add(.closing, phrases["brief.\(tone).closing.onDemand"])
        case let .alarm(snoozeMinutes):
            add(.closing, phrases.format("brief.\(tone).closing.alarm", snoozeMinutes))
        }
        return Briefing(languageCode: persona.languageCode, lines: lines)
    }

    // MARK: Alarm conversation

    /// What the butler says when an alarm goes off: the greeting and time, which alarm this is,
    /// the next item coming up, and the question — dismiss, or remind again in `snoozeMinutes`?
    /// `forSoundFile`: the version recorded into the alarm's sound (heard with the app closed),
    /// which ends by pointing at the Respond button.
    public func alarmAnnouncement(alarmLabel: String, items: [RankedItem], now: Date, snoozeMinutes: Int, forSoundFile: Bool = false) -> Briefing {
        var lines: [BriefingLine] = []
        func add(_ kind: BriefingLine.Kind, _ text: String) {
            guard let text = text.nonBlank else { return }
            lines.append(BriefingLine(id: lines.count, kind: kind, text: text))
        }
        add(.greeting, greeting(now: now))
        add(.time, phrases.format("brief.\(tone).time", time(now)))
        if let label = alarmLabel.nonBlank {
            add(.item, phrases.format("brief.\(tone).alarm.this", speakTitles ? label : phrases["brief.private"]))
        } else {
            add(.item, phrases["brief.\(tone).alarm.thisNoLabel"])
        }
        if let next = nextItem(items, now: now) {
            if next.item.kind == .event {
                add(.next, nextLine(next, now: now))
            } else {
                let key = next.item.isOverdue ? "brief.\(tone).overdue" : "brief.\(tone).reminderItem"
                add(.reminder, phrases.format(key, title(next.item)))
            }
            if next.importance == .high { add(.important, phrases["brief.\(tone).important"]) }
        } else {
            add(.next, phrases["brief.\(tone).noEvents"])
        }
        add(.closing, phrases.format("brief.\(tone).alarm.ask", snoozeMinutes))
        if forSoundFile { add(.closing, phrases["brief.\(tone).alarm.respondHint"]) }
        return Briefing(languageCode: persona.languageCode, lines: lines)
    }

    /// The butler's reply once the person has answered.
    public func acknowledgement(_ reply: AlarmReply, remindAt date: Date?, snoozeMinutes: Int) -> String {
        switch reply {
        case .dismiss:
            return phrases["brief.\(tone).ack.dismiss"]
        case .remindIn, .remindAt:
            return phrases.format("brief.\(tone).ack.remind", time(date ?? Date()))
        case .repeatPrompt, .unknown:
            return phrases.format("brief.\(tone).ack.unclear", snoozeMinutes)
        }
    }

    /// Said when nobody answers: the alarm will ring again at `date`.
    public func noAnswer(remindAt date: Date) -> String {
        phrases.format("brief.\(tone).ack.noAnswer", time(date))
    }

    /// The event under way or next today, else the most important due reminder.
    func nextItem(_ items: [RankedItem], now: Date) -> RankedItem? {
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let event = items
            .filter { $0.item.kind == .event && !$0.item.isAllDay }
            .filter { ($0.item.endDate ?? $0.item.date ?? now) > now && ($0.item.date ?? now) < endOfDay }
            .min { ($0.item.date ?? now) < ($1.item.date ?? now) }
        if let event { return event }
        return items
            .filter { $0.item.kind == .reminder }
            .max { ($0.importance, $1.item.date ?? Date.distantFuture) < ($1.importance, $0.item.date ?? Date.distantFuture) }
    }

    // MARK: Pieces

    func greeting(now: Date) -> String {
        let hour = calendar.component(.hour, from: now)
        let part = switch hour {
        case 4..<12: "morning"
        case 12..<17: "afternoon"
        case 17..<22: "evening"
        default: "night"
        }
        let text = phrases.format("brief.\(tone).greeting.\(part)", persona.displayName)
        if persona.languageCode == "en", persona.tone != .professional, persona.accent.region == .southernUS, part == "morning" {
            return "Well, " + text.prefix(1).lowercased() + text.dropFirst()
        }
        return text
    }

    func nextLine(_ next: RankedItem, now: Date) -> String {
        let start = next.item.date ?? now
        if start <= now {
            return phrases.format("brief.\(tone).nextNow", title(next.item), time(start))
        }
        let line = phrases.format("brief.\(tone).next", title(next.item), time(start), relative(from: now, to: start))
        guard let summary = summary(next.item) else { return line }
        return line + " " + summary
    }

    func itemLine(_ ranked: RankedItem) -> String {
        let line = phrases.format("brief.\(tone).item", title(ranked.item), time(ranked.item.date ?? Date()))
        let marked = ranked.importance == .high ? line + " " + phrases["brief.\(tone).important"] : line
        guard persona.length == .full, let summary = summary(ranked.item) else { return marked }
        return marked + " " + summary
    }

    /// "At Dr. Smith's office, for 45 minutes, with 3 others." (only what is known).
    func summary(_ item: BriefingItem) -> String? {
        var parts: [String] = []
        if speakTitles, let location = item.location {
            parts.append(phrases.format("brief.summary.at", String(location.prefix(60))))
        }
        if let minutes = item.durationMinutes {
            parts.append(phrases.format("brief.summary.for", duration(minutes: minutes)))
        }
        if item.attendeeCount > 0 {
            parts.append(phrases.format("brief.summary.with", item.attendeeCount))
        }
        guard !parts.isEmpty else { return nil }
        var sentence = parts.joined(separator: Self.listSeparator(persona.languageCode))
        if let first = sentence.first { sentence = first.uppercased() + sentence.dropFirst() }
        return sentence + Self.sentenceEnd(persona.languageCode)
    }

    func title(_ item: BriefingItem) -> String {
        guard speakTitles else { return phrases["brief.private"] }
        return item.title.nonBlank ?? phrases["brief.private"]
    }

    /// "7:00 AM" / "07:00", in the briefing language.
    func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
    }

    /// "2 hours, 15 minutes" in the briefing language (whole minutes, rounded up).
    func relative(from now: Date, to date: Date) -> String {
        let minutes = max(1, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
        return duration(minutes: minutes)
    }

    func duration(minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        var formatterCalendar = calendar
        formatterCalendar.locale = locale
        formatter.calendar = formatterCalendar
        formatter.unitsStyle = .full
        formatter.allowedUnits = minutes >= 60 ? [.hour, .minute] : [.minute]
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes)"
    }

    /// ", " in most languages; the language's own comma where it differs.
    static func listSeparator(_ languageCode: String) -> String {
        switch languageCode {
        case "zh-Hans": "，"
        case "ar", "ur": "، "
        default: ", "
        }
    }

    /// The full stop of the briefing language.
    static func sentenceEnd(_ languageCode: String) -> String {
        switch languageCode {
        case "zh-Hans": "。"
        case "hi", "bn": "।"
        case "ur": "۔"
        default: "."
        }
    }

    /// A touch of regional wording for the North American English accents (not in the
    /// Professional tone, which stays formal).
    func regionalFlourish() -> String? {
        guard persona.languageCode == "en", persona.tone != .professional else { return nil }
        switch persona.accent.region {
        case .southernUS: return "Y'all have a good one now."
        case .canadian: return "Have a good one, eh."
        case .british, .indian: return nil
        }
    }
}

/// Speaking speed and pitch for a persona (AVSpeechUtterance scale: rate 0…1 with 0.5 normal,
/// pitch 0.5…2 with 1 normal).
public struct Prosody: Sendable, Hashable {
    public var rate: Float
    public var pitch: Float

    public init(rate: Float, pitch: Float) {
        self.rate = rate
        self.pitch = pitch
    }

    public static func forPersona(_ persona: Persona) -> Prosody {
        var prosody = switch persona.tone {
        case .moderate: Prosody(rate: 0.5, pitch: 1.0)
        case .professional: Prosody(rate: 0.47, pitch: 0.95)
        case .child: Prosody(rate: 0.44, pitch: 1.1)
        case .unhinged: Prosody(rate: 0.55, pitch: 1.05)
        }
        if persona.usesAccent, persona.accent.region == .southernUS {
            // A slower, warmer delivery for the approximated Southern accent.
            prosody.rate -= 0.04
            prosody.pitch -= 0.03
        }
        return prosody
    }
}
