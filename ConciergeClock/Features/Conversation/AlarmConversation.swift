import ConciergeCore
import Foundation
import Observation

/// The conversation when an alarm goes off, always on the loudspeaker:
///
/// 1. The ring is silenced and the butler says the time, which alarm this is and what comes
///    next, then asks: dismiss the alarm, or remind you again?
/// 2. He listens (speech recognised on the iPhone) and works out the answer — fixed rules for
///    the common phrases, the offline AI (Gemma) for anything else, in any app language.
/// 3. He does it — dismiss, or a new ring in N minutes / at a time — and says so.
///
/// "Repeat" says it again; a reply he cannot understand gets one clarifying question. If nobody
/// answers twice, he reminds again after the snooze length, so a sleeper is never left without
/// an alarm. Big buttons do the same things for anyone who prefers to tap.
@MainActor
@Observable
final class AlarmConversation: Identifiable {
    enum Phase: Equatable {
        case starting
        case speaking
        case listening
        case thinking
        case done(String)
        /// Listening is not possible (permission, or no on-device recognition for the language).
        case buttonsOnly(String)
    }

    let id = UUID()
    let ringID: String
    let alarm: Alarm?
    private(set) var phase: Phase = .starting
    /// What was heard last.
    private(set) var heard = ""
    /// The announcement being spoken (shown as text).
    private(set) var announcement: Briefing?

    private unowned let model: AppModel
    private let listener = ListeningService()
    @ObservationIgnored private var task: Task<Void, Never>?

    init(ringID: String, alarm: Alarm?, model: AppModel) {
        self.ringID = ringID
        self.alarm = alarm
        self.model = model
    }

    private var settings: AppSettings { model.settings.settings }
    private var persona: Persona { settings.persona(for: alarm) }
    private var snoozeMinutes: Int { settings.snoozeMinutes(for: alarm) }
    private var builder: BriefingBuilder { BriefingBuilder(persona: persona, speakTitles: settings.speakEventTitles) }

    func start() {
        guard task == nil else { return }
        task = Task { await run() }
    }

    // MARK: The conversation

    private func run() async {
        model.scheduler.silenceForConversation(ringID: ringID)
        await model.briefings.refresh()
        let announcement = builder.alarmAnnouncement(
            alarmLabel: alarm?.label ?? "", items: model.briefings.items, now: Date(), snoozeMinutes: snoozeMinutes
        )
        self.announcement = announcement
        phase = .speaking
        await model.speech.speakAndWait(announcement, persona: persona, loudspeaker: true)
        guard !Task.isCancelled else { return }

        // Listening needs the microphone and speech recognition, on the iPhone.
        if ListeningService.permission == .notDetermined {
            _ = await ListeningService.requestPermission()
        }
        let locales = persona.usesAccent ? persona.accent.preferredLocales : VoiceCatalog.speechLocales(for: persona.languageCode)
        guard ListeningService.permission == .granted, let recognizer = ListeningService.recognizer(for: locales) else {
            SpeechService.endConversationSession()
            phase = .buttonsOnly(ListeningService.permission == .granted ? model.l10n["conversation.noRecognizer"] : model.l10n["conversation.noPermission"])
            return
        }

        var silences = 0
        var unclear = 0
        while !Task.isCancelled {
            phase = .listening
            let text = await listener.listen(with: recognizer)
            guard !Task.isCancelled else { return }
            heard = text
            if text.isEmpty {
                silences += 1
                if silences >= 2 {
                    // Nobody answered: ring again after the snooze length.
                    let date = Date().addingTimeInterval(TimeInterval(snoozeMinutes * 60))
                    await say(builder.noAnswer(remindAt: date))
                    await model.scheduler.remindAgain(ringID: ringID, at: date)
                    finish(model.l10n("conversation.done.remind", model.l10n.time(date)))
                    return
                }
                await say(builder.acknowledgement(.unknown, remindAt: nil, snoozeMinutes: snoozeMinutes))
                continue
            }
            phase = .thinking
            let reply = await interpret(text)
            switch reply {
            case .dismiss:
                await perform(.dismiss, method: .voice)
                return
            case .remindIn, .remindAt:
                await perform(reply, method: .voice)
                return
            case .repeatPrompt:
                phase = .speaking
                await model.speech.speakAndWait(announcement, persona: persona, loudspeaker: true)
            case .unknown:
                unclear += 1
                if unclear >= 3 {
                    let date = Date().addingTimeInterval(TimeInterval(snoozeMinutes * 60))
                    await say(builder.noAnswer(remindAt: date))
                    await model.scheduler.remindAgain(ringID: ringID, at: date)
                    finish(model.l10n("conversation.done.remind", model.l10n.time(date)))
                    return
                }
                await say(builder.acknowledgement(.unknown, remindAt: nil, snoozeMinutes: snoozeMinutes))
            }
        }
    }

    /// Rules first (instant); the offline AI for what the rules do not recognise.
    private func interpret(_ text: String) async -> AlarmReply {
        let byRules = AlarmReplyParser.parse(text, defaultSnoozeMinutes: snoozeMinutes)
        guard byRules == .unknown, let generator = model.models.textGenerator(interactive: true) else { return byRules }
        return await ModelAlarmReplyInterpreter.interpret(text, using: generator, defaultSnoozeMinutes: snoozeMinutes) ?? .unknown
    }

    private func say(_ text: String) async {
        phase = .speaking
        await model.speech.speakAndWait(Briefing(languageCode: persona.languageCode, lines: [BriefingLine(id: 0, kind: .closing, text: text)]), persona: persona, loudspeaker: true)
    }

    // MARK: Actions (voice or buttons)

    /// Does what was asked and says so.
    func perform(_ reply: AlarmReply, method: DismissMethod) async {
        listener.stop()
        switch reply {
        case .dismiss:
            await model.scheduler.dismiss(ringID: ringID, method: method)
            await say(builder.acknowledgement(.dismiss, remindAt: nil, snoozeMinutes: snoozeMinutes))
            finish(model.l10n["conversation.done.dismissed"])
        case .remindIn, .remindAt:
            let date = reminderDate(for: reply, now: Date()) ?? Date().addingTimeInterval(TimeInterval(snoozeMinutes * 60))
            await model.scheduler.remindAgain(ringID: ringID, at: date)
            await say(builder.acknowledgement(reply, remindAt: date, snoozeMinutes: snoozeMinutes))
            finish(model.l10n("conversation.done.remind", model.l10n.time(date)))
        case .repeatPrompt, .unknown:
            break
        }
    }

    /// A button: stop the voice loop and act.
    func tap(_ reply: AlarmReply) {
        task?.cancel()
        model.speech.stop()
        listener.stop()
        task = Task { await perform(reply, method: .button) }
    }

    func tapRepeat() {
        guard let announcement else { return }
        task?.cancel()
        listener.stop()
        task = Task {
            phase = .speaking
            await model.speech.speakAndWait(announcement, persona: persona, loudspeaker: true)
            phase = .buttonsOnly(model.l10n["conversation.tapToAnswer"])
        }
    }

    private func finish(_ message: String) {
        SpeechService.endConversationSession()
        phase = .done(message)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self else { return }
            self.model.endAlarmConversation(self)
        }
    }

    /// Closing the screen without answering counts as dismissing.
    func close() {
        task?.cancel()
        model.speech.stop()
        listener.stop()
        if case .done = phase {
            model.endAlarmConversation(self)
            return
        }
        Task {
            await model.scheduler.dismiss(ringID: ringID, method: .button)
            SpeechService.endConversationSession()
            model.endAlarmConversation(self)
        }
    }
}
