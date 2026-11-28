import Foundation

/// What the person wants done with a ringing alarm, worked out from what they said.
public enum AlarmReply: Sendable, Hashable {
    /// Stop the alarm ("dismiss", "I'm up", "stop", "OK").
    case dismiss
    /// Ring again after this many minutes ("remind me in 10 minutes", "snooze", "half an hour").
    case remindIn(minutes: Int)
    /// Ring again at this time of day ("remind me at quarter past seven").
    case remindAt(hour: Int, minute: Int)
    /// Say it again.
    case repeatPrompt
    /// Not understood.
    case unknown
}

/// Understands short spoken replies with fixed rules: the common phrases in every app language,
/// spoken numbers in English, digits in any language. Deterministic and instant; the offline AI
/// (`ModelAlarmReplyInterpreter`) handles everything these rules do not recognise.
public enum AlarmReplyParser {
    public static func parse(_ transcript: String, defaultSnoozeMinutes: Int) -> AlarmReply {
        let text = DayOffRules.normalize(transcript)
        let spaced = " " + DayOffRules.tokens(text) + " "
        func has(_ phrases: [String]) -> Bool {
            phrases.contains { phrase in
                let normalized = DayOffRules.normalize(phrase)
                return normalized.unicodeScalars.allSatisfy(\.isASCII)
                    ? spaced.contains(" " + DayOffRules.tokens(normalized) + " ")
                    : text.contains(normalized)
            }
        }
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return .unknown }

        if has(repeatWords) { return .repeatPrompt }

        // "Remind me at 7:15" / "at quarter past seven" / "a las 7" / "à 7 heures" / "07:30".
        if let time = clockTime(in: spaced, raw: text) {
            return .remindAt(hour: time.hour, minute: time.minute)
        }
        if has(remindWords) || has(["more", "minutes", "minute", "hour"]) {
            if let minutes = duration(in: spaced, raw: text) {
                return .remindIn(minutes: minutes.clamped(to: Snooze.minuteRange))
            }
            return .remindIn(minutes: defaultSnoozeMinutes)
        }
        if let minutes = duration(in: spaced, raw: text), has(["minutes", "minute", "min", "mins", "hour", "hours", "half"]) {
            return .remindIn(minutes: minutes.clamped(to: Snooze.minuteRange))
        }
        if has(dismissWords) { return .dismiss }
        return .unknown
    }

    // MARK: Vocabulary (all app languages)

    static let dismissWords = [
        "dismiss", "stop", "stop alarm", "turn it off", "turn off", "off", "i'm awake", "im awake", "i am awake", "awake",
        "i'm up", "im up", "i am up", "up", "ok", "okay", "got it", "i understand", "understood", "yes i will go", "i will go",
        "i'll go", "ill go", "on my way", "done", "cancel", "no thanks", "no thank you", "enough", "quiet",
        "arrête", "arrêter", "réveillé", "réveillée", "je suis debout", "d'accord", "c'est bon",
        "detener", "apaga", "apagar", "despierto", "despierta", "vale", "ya", "listo",
        "parar", "desligar", "acordei", "acordado", "acordada", "tá bom", "certo",
        "hentikan", "matikan", "sudah bangun", "oke", "baik",
        "停止", "关掉", "关闭", "我醒了", "起来了", "好的", "知道了",
        "बंद", "रोको", "उठ गया", "उठ गई", "ठीक है", "समझ गया",
        "بند کرو", "اٹھ گیا", "اٹھ گئی", "ٹھیک ہے",
        "أوقف", "إيقاف", "استيقظت", "حسنًا", "حسنا", "تمام",
        "עצור", "תפסיק", "התעוררתי", "קמתי", "בסדר", "אוקיי",
        "বন্ধ", "থামাও", "উঠেছি", "ঠিক আছে",
    ]

    static let remindWords = [
        "remind", "remind me", "snooze", "later", "again", "a bit", "a little", "give me", "five more", "not yet", "wait",
        "rappelle", "plus tard", "encore", "répète dans", "recuérdame", "más tarde", "pospón", "posponer", "otra vez",
        "lembra", "lembre", "mais tarde", "soneca", "de novo", "ingatkan", "nanti", "tunda", "lagi",
        "提醒", "稍后", "再睡", "等一下", "याद दिला", "बाद में", "स्नूज़", "फिर से",
        "یاد دلا", "بعد میں", "اسنوز", "ذكرني", "لاحقا", "لاحقًا", "غفوة", "תזכיר", "אחר כך", "נודניק",
        "মনে করিয়ে", "পরে", "স্নুজ",
    ]

    static let repeatWords = [
        "repeat", "say again", "say that again", "what did you say", "pardon", "sorry what", "again please",
        "répète", "repite", "repete", "ulangi", "再说一遍", "दोहराओ", "دہراؤ", "كرر", "חזור", "আবার বলো",
    ]

    static let numberWords: [String: Int] = [
        "one": 1, "a": 1, "an": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
        "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "fifteen": 15, "twenty": 20, "twenty five": 25,
        "thirty": 30, "forty": 40, "forty five": 45, "fifty": 50, "sixty": 60, "ninety": 90,
    ]

    // MARK: Numbers

    /// Minutes in "10 minutes", "ten more minutes", "half an hour", "an hour", "1 hour 30".
    static func duration(in spaced: String, raw: String) -> Int? {
        if spaced.contains(" half an hour ") || spaced.contains(" half hour ") || spaced.contains(" demi heure ")
            || spaced.contains(" media hora ") || spaced.contains(" meia hora ") || raw.contains("半小时") || raw.contains("आधा घंटा") {
            return 30
        }
        if spaced.contains(" quarter of an hour ") || spaced.contains(" quarter hour ") { return 15 }
        let words = spaced.split(separator: " ").map(String.init)
        var total = 0
        var found = false
        var index = 0
        while index < words.count {
            var value: Int?
            if let digits = Int(words[index]) {
                value = digits
            } else if index + 1 < words.count, let pair = numberWords[words[index] + " " + words[index + 1]] {
                value = pair
                index += 1
            } else if let single = numberWords[words[index]] {
                value = single
            }
            if let value {
                // Look ahead for the unit (allowing "more" in between).
                var next = index + 1
                if next < words.count, words[next] == "more" { next += 1 }
                let unit = next < words.count ? words[next] : ""
                if unit.hasPrefix("hour") || unit == "h" || unit == "heure" || unit == "hora" || unit == "jam" {
                    total += value * 60
                    found = true
                } else if unit.hasPrefix("min") || unit == "minuto" || unit == "minutos" || unit == "menit" {
                    total += value
                    found = true
                } else if !["a", "an"].contains(words[index]) {
                    // A bare number ("give me 10") means minutes.
                    total += value
                    found = true
                }
            }
            index += 1
        }
        if !found {
            // Digits glued to non-Latin text ("10分钟", "10 मिनट").
            let digits = raw.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            if let first = digits.first { return first }
        }
        return found && total > 0 ? total : nil
    }

    /// Words that put a clock time after them: "at 7", "a las 7", "às 7", "à 7 heures", "pukul 7".
    static let timeMarkers: Set<String> = ["at", "a", "las", "as", "pukul"]

    /// "7:15", "at 7 15", "quarter past seven", "half past 6", "at seven thirty", "a las 7".
    /// Nil when no clock time is said (a bare "10" is minutes, not a time).
    static func clockTime(in spaced: String, raw: String) -> (hour: Int, minute: Int)? {
        let words = spaced.split(separator: " ").map(String.init)
        func number(_ word: String) -> Int? { Int(word) ?? numberWords[word] }
        // "7:15" written with a colon (any language).
        if let match = raw.firstMatch(of: /(\d{1,2}):(\d{2})/), let hour = Int(match.1), let minute = Int(match.2),
           (0...24).contains(hour), (0..<60).contains(minute) {
            return (hour % 24, minute)
        }
        // "quarter past seven", "half past six", "quarter to eight"
        for (index, word) in words.enumerated() where index + 2 < words.count {
            guard words[index + 1] == "past" || words[index + 1] == "to", let hour = number(words[index + 2]), (0...24).contains(hour) else { continue }
            let minutes: Int? = switch word {
            case "quarter": 15
            case "half": 30
            default: Int(word) ?? (["a", "an"].contains(word) ? nil : numberWords[word])
            }
            guard let minutes, minutes < 60 else { continue }
            return words[index + 1] == "past" ? (hour % 24, minutes) : ((hour + 23) % 24, 60 - minutes)
        }
        // "at 7 15" / "at seven thirty" / "at 7" / "a las 7" — but not "in a minute" or "at 10 minutes".
        for (index, word) in words.enumerated() where timeMarkers.contains(word) && index + 1 < words.count {
            var next = index + 1
            if words[next] == "las" || words[next] == "the" { next += 1 }
            guard next < words.count, let hour = Int(words[next]) ?? (["a", "an"].contains(words[next]) ? nil : numberWords[words[next]]),
                  (0...24).contains(hour) else { continue }
            let after = next + 1 < words.count ? words[next + 1] : ""
            if after == "more" || after.hasPrefix("min") || after == "minuto" || after == "minutos" || after == "menit" { continue }
            if (after.hasPrefix("hour") || after == "hora" || after == "horas" || after == "jam"), word != "a", word != "las", word != "as" { continue }
            if next + 1 < words.count, let minute = number(words[next + 1]), (0..<60).contains(minute) {
                return (hour % 24, minute)
            }
            return (hour % 24, 0)
        }
        return nil
    }
}

/// Asks the offline AI (Gemma) what the person meant, for replies the rules did not recognise,
/// in any of the app's languages. Returns nil when the model is unsure or fails.
public enum ModelAlarmReplyInterpreter {
    public static let schema = #"{"type":"object","properties":{"action":{"type":"string","enum":["dismiss","remind_in","remind_at","repeat","unknown"]},"minutes":{"type":"integer"},"time":{"type":"string"}},"required":["action"]}"#

    static let system = """
    An alarm is ringing. The assistant asked the person whether to dismiss the alarm or remind them \
    again. Classify their spoken reply (any language). dismiss: they are awake, acknowledge, will go, \
    or want it stopped. remind_in: remind or snooze after some minutes (give "minutes"; if no time is \
    said, omit it). remind_at: remind at a clock time (give "time" as 24-hour HH:mm). repeat: they \
    want the message again. unknown: anything else or unclear.
    """

    public static func interpret(_ transcript: String, using generator: any TextGenerating, defaultSnoozeMinutes: Int, now: Date = Date(), calendar: Calendar = .current) async -> AlarmReply? {
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let prompt = String(format: "Time now: %02d:%02d\nReply: \"%@\"", hour, minute, transcript.replacingOccurrences(of: "\"", with: "'"))
        guard let reply = try? await generator.generate(system: system, prompt: prompt, jsonSchema: schema, maxTokens: 60, temperature: 0) else { return nil }
        return parse(reply, defaultSnoozeMinutes: defaultSnoozeMinutes)
    }

    /// Reads `{"action":"remind_in","minutes":10}`, tolerating text around the JSON.
    public static func parse(_ reply: String, defaultSnoozeMinutes: Int) -> AlarmReply? {
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}"), start < end,
              let data = String(reply[start...end]).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = object["action"] as? String else { return nil }
        switch action {
        case "dismiss":
            return .dismiss
        case "remind_in":
            let minutes = (object["minutes"] as? Int) ?? (object["minutes"] as? String).flatMap { Int($0) } ?? defaultSnoozeMinutes
            return .remindIn(minutes: minutes.clamped(to: Snooze.minuteRange))
        case "remind_at":
            guard let time = object["time"] as? String else { return nil }
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
            return .remindAt(hour: parts[0], minute: parts[1])
        case "repeat":
            return .repeatPrompt
        default:
            return .unknown
        }
    }
}

/// The next ring time for a reply: `remindIn` from now, `remindAt` at the next time that clock
/// time comes round. Nil for replies that do not set a reminder.
public func reminderDate(for reply: AlarmReply, now: Date, calendar: Calendar = .current) -> Date? {
    switch reply {
    case let .remindIn(minutes):
        return now.addingTimeInterval(TimeInterval(minutes * 60))
    case let .remindAt(hour, minute):
        // "At 7" said in the evening means 19:00: try the hour, then 12 hours later, then tomorrow.
        guard let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { return nil }
        var candidates = [today]
        if hour < 12, let evening = calendar.date(byAdding: .hour, value: 12, to: today) { candidates.append(evening) }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) { candidates.append(tomorrow) }
        return candidates.first { $0 > now }
    default:
        return nil
    }
}
