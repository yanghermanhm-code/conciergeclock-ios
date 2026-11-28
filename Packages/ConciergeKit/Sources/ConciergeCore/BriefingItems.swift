import Foundation

/// One thing the butler may mention: a calendar event or a reminder. Built by the app from
/// EventKit on the iPhone; never stored (docs/DECISIONS.md, privacy).
public struct BriefingItem: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable {
        case event, reminder
    }

    public var id: String
    public var kind: Kind
    public var title: String
    /// Events: the start. Reminders: the due date (nil = no time).
    public var date: Date?
    public var endDate: Date?
    public var isAllDay: Bool
    public var location: String?
    /// Other people invited (events).
    public var attendeeCount: Int
    /// The calendar or list name ("Work", "Family").
    public var calendarTitle: String
    /// The first part of the notes, for the importance judgement only (never spoken).
    public var notesSnippet: String?
    /// Reminders: 1 = high … 9 = low, 0 = none (EventKit's scale).
    public var priority: Int
    public var isOverdue: Bool

    public init(
        id: String, kind: Kind, title: String, date: Date?, endDate: Date? = nil, isAllDay: Bool = false,
        location: String? = nil, attendeeCount: Int = 0, calendarTitle: String = "", notesSnippet: String? = nil,
        priority: Int = 0, isOverdue: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.date = date
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location?.nonBlank
        self.attendeeCount = max(0, attendeeCount)
        self.calendarTitle = calendarTitle
        self.notesSnippet = notesSnippet?.nonBlank.map { String($0.prefix(240)) }
        self.priority = priority
        self.isOverdue = isOverdue
    }

    /// Minutes the event lasts, when it has an end and is not all-day.
    public var durationMinutes: Int? {
        guard !isAllDay, let date, let endDate, endDate > date else { return nil }
        return Int(endDate.timeIntervalSince(date) / 60)
    }
}

/// Whether something deserves a mention as important.
public enum Importance: String, Codable, Sendable, Hashable, Comparable {
    case low, normal, high

    private var rank: Int {
        switch self {
        case .low: 0
        case .normal: 1
        case .high: 2
        }
    }

    public static func < (lhs: Importance, rhs: Importance) -> Bool { lhs.rank < rhs.rank }
}

/// Who judged the importance (shown in the Concierge tab).
public enum ImportanceSource: String, Sendable, Hashable {
    case rules, offlineAI
}

/// An item with its importance, ready for the script.
public struct RankedItem: Sendable, Hashable, Identifiable {
    public var item: BriefingItem
    public var importance: Importance
    public var source: ImportanceSource

    public init(item: BriefingItem, importance: Importance, source: ImportanceSource) {
        self.item = item
        self.importance = importance
        self.source = source
    }

    public var id: String { item.id }
}

/// The built-in importance judgement, used on every iPhone and whenever the offline AI is off,
/// not downloaded or too slow. Deterministic and explainable.
public enum ImportanceRules {
    /// Words that usually mark something that matters (English plus the other app languages'
    /// most common equivalents). Whole-word match for Latin scripts.
    public static let keywords = [
        "interview", "exam", "test", "flight", "doctor", "dentist", "hospital", "surgery", "appointment",
        "deadline", "due", "court", "meeting with", "presentation", "pitch", "review", "wedding", "funeral",
        "school", "pick up", "pickup", "vet", "train", "bus", "airport", "visa", "bank", "payment", "bill",
        "rendez-vous", "médecin", "examen", "entrevista", "médico", "cita", "consulta", "prova", "entrevista",
        "dokter", "ujian", "wawancara", "面试", "考试", "医生", "航班", "डॉक्टर", "परीक्षा", "انٹرویو", "ڈاکٹر",
        "مقابلة", "طبيب", "امتحان", "ראיון", "רופא", "מבחן", "ডাক্তার", "পরীক্ষা",
    ]

    public static func judge(_ item: BriefingItem) -> Importance {
        var score = 0
        let title = DayOffRules.normalize(item.title)
        let spaced = " " + DayOffRules.tokens(title) + " "
        if keywords.contains(where: { word in
            let normalized = DayOffRules.normalize(word)
            return normalized.unicodeScalars.allSatisfy(\.isASCII)
                ? spaced.contains(" " + DayOffRules.tokens(normalized) + " ")
                : title.contains(normalized)
        }) {
            score += 2
        }
        if item.attendeeCount >= 2 { score += 1 }
        if item.kind == .reminder {
            if item.isOverdue { score += 2 }
            if (1...4).contains(item.priority) { score += 2 }
        }
        if let minutes = item.durationMinutes, minutes >= 120 { score += 1 }
        if let date = item.date, !item.isAllDay {
            let hour = Calendar.current.component(.hour, from: date)
            if hour < 7 { score += 1 } // Unusually early: worth a mention.
        }
        if item.kind == .event, item.isAllDay, item.attendeeCount == 0 { score -= 1 }
        switch score {
        case 2...: return .high
        case ..<0: return .low
        default: return .normal
        }
    }

    public static func rank(_ items: [BriefingItem]) -> [RankedItem] {
        items.map { RankedItem(item: $0, importance: judge($0), source: .rules) }
    }
}

/// Asks the offline AI (Gemma) which items are important. The model sees titles, times,
/// durations, places, invitee counts and a short notes snippet — on the iPhone only — and
/// replies with JSON. Anything it cannot answer keeps the rules' judgement; facts are never
/// taken from it.
public enum ModelImportanceRanker {
    public static let schema = #"{"type":"object","properties":{"items":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"important":{"type":"boolean"}},"required":["id","important"]}}},"required":["items"]}"#

    static let system = """
    You help a personal assistant decide which of today's calendar events and reminders are \
    important enough to point out when waking someone up. Important: things with real \
    consequences if missed or late (interviews, exams, medical appointments, travel, deadlines, \
    meetings with others, picking someone up, payments). Not important: routine or optional \
    items, all-day markers, personal reminders with no time pressure. Judge each item by its id. \
    Mark at most about a third of the items as important.
    """

    /// The prompt for `items` (one line per item, with a stable short id).
    public static func prompt(for items: [BriefingItem], now: Date, calendar: Calendar = .current) -> String {
        var lines = ["Now: \(stamp(now, calendar: calendar))", "Items:"]
        for (index, item) in items.enumerated() {
            var parts = ["id=\(index)", item.kind.rawValue, "title=\"\(item.title.replacingOccurrences(of: "\"", with: "'"))\""]
            if item.isAllDay {
                parts.append("all-day")
            } else if let date = item.date {
                parts.append("time=\(stamp(date, calendar: calendar))")
            }
            if let minutes = item.durationMinutes { parts.append("minutes=\(minutes)") }
            if let location = item.location { parts.append("place=\"\(location.prefix(60))\"") }
            if item.attendeeCount > 0 { parts.append("others=\(item.attendeeCount)") }
            if item.kind == .reminder {
                if item.isOverdue { parts.append("overdue") }
                if item.priority > 0 { parts.append("priority=\(item.priority)") }
            }
            if !item.calendarTitle.isEmpty { parts.append("list=\"\(item.calendarTitle.prefix(40))\"") }
            if let notes = item.notesSnippet { parts.append("notes=\"\(notes.prefix(160).replacingOccurrences(of: "\n", with: " "))\"") }
            lines.append(parts.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }

    /// Ranks `items` with `generator`; items the reply does not cover keep the rules' result.
    /// Returns nil when the model fails or replies with nothing usable.
    public static func rank(_ items: [BriefingItem], using generator: any TextGenerating, now: Date = Date()) async -> [RankedItem]? {
        guard !items.isEmpty else { return [] }
        let limited = Array(items.prefix(30))
        guard let reply = try? await generator.generate(
            system: system, prompt: prompt(for: limited, now: now), jsonSchema: schema,
            maxTokens: 40 + 20 * limited.count, temperature: 0
        ), let verdicts = parse(reply), !verdicts.isEmpty else { return nil }
        let rules = ImportanceRules.rank(items)
        return rules.enumerated().map { index, ranked in
            guard let important = verdicts[index] else { return ranked }
            // The model decides high vs normal; the rules' "low" (all-day markers) stays low
            // unless the model calls it important.
            let importance: Importance = important ? .high : (ranked.importance == .low ? .low : .normal)
            return RankedItem(item: ranked.item, importance: importance, source: .offlineAI)
        }
    }

    /// Reads `{"items":[{"id":"0","important":true},…]}`, tolerating text around the JSON and
    /// numeric ids.
    public static func parse(_ reply: String) -> [Int: Bool]? {
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}"), start < end,
              let data = String(reply[start...end]).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = object["items"] as? [[String: Any]] else { return nil }
        var result: [Int: Bool] = [:]
        for entry in list {
            let id: Int? = (entry["id"] as? Int) ?? (entry["id"] as? String).flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard let id, let important = entry["important"] as? Bool else { continue }
            result[id] = important
        }
        return result
    }

    private static func stamp(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: date)
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let day = days[((parts.weekday ?? 1) - 1 + 7) % 7]
        return String(format: "%@ %04d-%02d-%02d %02d:%02d", day, parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0)
    }
}
