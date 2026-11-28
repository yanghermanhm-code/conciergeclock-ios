import ConciergeCore
import Foundation
import Observation

/// Today's items for the butler and the briefing built from them.
///
/// `refresh()` reads the calendars and reminders (on the iPhone), judges importance with the
/// built-in rules at once, then — when the offline AI is ready — lets Gemma judge again in the
/// background and updates the list. "Brief Me Now" speaks whatever is ready, so it never waits
/// for the model.
@MainActor
@Observable
final class BriefingService {
    private(set) var items: [RankedItem] = []
    /// Gemma is judging importance right now.
    private(set) var isRanking = false
    private(set) var lastRefresh: Date?

    private let calendars: CalendarService
    private let settings: SettingsStore
    private let models: ModelService
    @ObservationIgnored private var rankTask: Task<Void, Never>?
    /// Gemma's verdicts, kept while the items do not change (keyed by the items' signature).
    @ObservationIgnored private var modelCache: (signature: [String], ranked: [RankedItem])?
    @ObservationIgnored private var variation = 0

    init(calendars: CalendarService, settings: SettingsStore, models: ModelService) {
        self.calendars = calendars
        self.settings = settings
        self.models = models
    }

    /// Whether importance currently comes from the offline AI.
    var usesOfflineAI: Bool {
        items.contains { $0.source == .offlineAI }
    }

    /// Re-reads today's events and reminders and ranks them.
    func refresh(now: Date = Date()) async {
        let current = settings.settings
        let found = await calendars.briefingItems(
            excludingCalendars: Set(current.excludedCalendarIDs),
            excludingLists: Set(current.excludedReminderListIDs),
            now: now
        )
        lastRefresh = now
        let signature = found.map { "\($0.id)|\($0.title)|\($0.date?.timeIntervalSince1970 ?? 0)" }
        if let cache = modelCache, cache.signature == signature {
            items = cache.ranked
            return
        }
        items = ImportanceRules.rank(found)
        rankWithModel(found, signature: signature, now: now)
    }

    /// Stops Gemma's ranking (the app is going to the background, where iOS does not allow GPU
    /// work); the next refresh starts it again.
    func cancelRanking() {
        rankTask?.cancel()
        rankTask = nil
        isRanking = false
    }

    private func rankWithModel(_ found: [BriefingItem], signature: [String], now: Date) {
        rankTask?.cancel()
        isRanking = false
        guard let generator = models.textGenerator(), !found.isEmpty else { return }
        isRanking = true
        rankTask = Task { [weak self] in
            let ranked = await ModelImportanceRanker.rank(found, using: generator, now: now)
            guard let self, !Task.isCancelled else { return }
            self.isRanking = false
            guard let ranked else { return }
            self.modelCache = (signature, ranked)
            self.items = ranked
        }
    }

    /// The script for `trigger` with today's items (Settings' persona unless one is given).
    func briefing(trigger: BriefingTrigger = .onDemand, persona: Persona? = nil, now: Date = Date()) -> Briefing {
        variation += 1
        let builder = BriefingBuilder(
            persona: persona ?? settings.settings.persona(),
            speakTitles: settings.settings.speakEventTitles
        )
        return builder.build(items: items, now: now, trigger: trigger, variation: variation)
    }

    /// A short sample in the persona's language and tone (voice preview): the greeting, the time
    /// and a dentist appointment at 9:15.
    func sample(for persona: Persona, now: Date = Date()) -> Briefing {
        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
        let dentist = calendar.date(bySettingHour: 9, minute: 15, second: 0, of: now) ?? now
        let phrases = PhraseBook(languageCode: persona.languageCode)
        let item = BriefingItem(
            id: "sample", kind: .event, title: phrases["brief.sample.dentist"], date: dentist,
            endDate: dentist.addingTimeInterval(45 * 60)
        )
        var short = persona
        short.length = .quick
        let builder = BriefingBuilder(persona: short, phrases: phrases)
        var briefing = builder.build(
            items: [RankedItem(item: item, importance: .high, source: .rules)], now: morning,
            trigger: .alarm(snoozeMinutes: settings.settings.defaultSnoozeMinutes)
        )
        // Greeting, time, next event, "important" and the closing question are enough.
        briefing.lines = briefing.lines.filter { $0.kind != .count && $0.kind != .reminder }
        return briefing
    }
}
