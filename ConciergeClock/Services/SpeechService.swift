import AVFoundation
import ConciergeCore
import Foundation
import Observation

/// Speaks briefings and previews with the iPhone's own voices (AVSpeechSynthesizer), on the
/// iPhone, offline. The bundled offline voice engine arrives in Phase 7 behind the same API.
///
/// Audio: `.playback` with the spoken-audio mode, so other audio dips while the butler talks and
/// the sound comes from the loudspeaker (headphones, if connected, are respected for previews).
/// Wake-up announcements (Phase 3) use a session forced to the loudspeaker.
@MainActor
@Observable
final class SpeechService: NSObject {
    enum State: Equatable {
        case idle, speaking
    }

    private(set) var state: State = .idle
    /// The line being spoken (highlighted on screen).
    private(set) var currentLineID: Int?
    /// The briefing being spoken, if any.
    private(set) var current: Briefing?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var lineForUtterance: [ObjectIdentifier: Int] = [:]
    @ObservationIgnored private var lastUtterance: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks `briefing` line by line in the persona's voice. Stops anything already speaking.
    func speak(_ briefing: Briefing, persona: Persona) {
        stop()
        activateSession()
        let voice = VoiceCatalog.voice(for: persona)
        let prosody = Prosody.forPersona(persona)
        current = briefing
        for line in briefing.lines {
            let utterance = AVSpeechUtterance(string: line.text)
            utterance.voice = voice
            utterance.rate = prosody.rate
            utterance.pitchMultiplier = prosody.pitch
            utterance.postUtteranceDelay = 0.25
            lineForUtterance[ObjectIdentifier(utterance)] = line.id
            lastUtterance = ObjectIdentifier(utterance)
            synthesizer.speak(utterance)
        }
        state = briefing.lines.isEmpty ? .idle : .speaking
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finish()
    }

    private func finish() {
        state = .idle
        currentLineID = nil
        current = nil
        lineForUtterance = [:]
        lastUtterance = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    fileprivate func didStart(_ id: ObjectIdentifier) {
        currentLineID = lineForUtterance[id]
    }

    fileprivate func didEnd(_ id: ObjectIdentifier) {
        if id == lastUtterance { finish() }
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.didStart(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.didEnd(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.didEnd(id) }
    }
}

/// Chooses the iPhone voice for a persona: the accent's locale (English) or the briefing
/// language, the persona's gender when such a voice exists, and the best quality installed
/// (Premium, then Enhanced, then the default). Novelty and Personal Voices are never used.
enum VoiceCatalog {
    enum Quality: Int, Comparable {
        case standard, enhanced, premium

        init(_ quality: AVSpeechSynthesisVoiceQuality) {
            switch quality {
            case .premium: self = .premium
            case .enhanced: self = .enhanced
            default: self = .standard
            }
        }

        static func < (lhs: Quality, rhs: Quality) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// The speech locale used for each briefing language (other than English).
    static func speechLocales(for languageCode: String) -> [String] {
        switch languageCode {
        case "fr": ["fr-FR", "fr-CA"]
        case "es": ["es-ES", "es-MX", "es-US"]
        case "zh-Hans": ["zh-CN"]
        case "hi": ["hi-IN"]
        case "ur": ["ur-PK", "ur-IN"]
        case "ar": ["ar-SA", "ar-001"]
        case "he": ["he-IL"]
        case "pt-BR": ["pt-BR", "pt-PT"]
        case "bn": ["bn-IN", "bn-BD"]
        case "id": ["id-ID"]
        default: ["en-US", "en-GB"]
        }
    }

    static var installedVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter {
            !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice)
        }
    }

    /// The voices that can speak `persona`, best first.
    static func candidates(for persona: Persona) -> [AVSpeechSynthesisVoice] {
        let locales = persona.usesAccent ? persona.accent.preferredLocales : speechLocales(for: persona.languageCode)
        let wanted: AVSpeechSynthesisVoiceGender = persona.accent.gender == .male ? .male : .female
        let voices = installedVoices
        for locale in locales {
            let matches = voices.filter { $0.language == locale }
            guard !matches.isEmpty else { continue }
            return matches.sorted { lhs, rhs in
                let lhsGender = lhs.gender == wanted ? 1 : 0
                let rhsGender = rhs.gender == wanted ? 1 : 0
                if lhsGender != rhsGender { return lhsGender > rhsGender }
                return Quality(lhs.quality) > Quality(rhs.quality)
            }
        }
        // Any voice of the language (e.g. "ar" when only another region is installed).
        let base = persona.usesAccent ? "en" : String(persona.languageCode.prefix(2))
        return voices.filter { $0.language.hasPrefix(base) }.sorted { Quality($0.quality) > Quality($1.quality) }
    }

    static func voice(for persona: Persona) -> AVSpeechSynthesisVoice? {
        candidates(for: persona).first
    }

    /// What Settings shows about the chosen voice.
    struct Summary: Equatable {
        var name: String?
        var quality: Quality?
        /// The voice is not the persona's gender or exact locale (a closer one can be downloaded).
        var isApproximate: Bool
        /// A better-quality voice could be downloaded for this accent or language.
        var canImprove: Bool
    }

    static func summary(for persona: Persona) -> Summary {
        guard let voice = voice(for: persona) else {
            return Summary(name: nil, quality: nil, isApproximate: true, canImprove: true)
        }
        let locales = persona.usesAccent ? persona.accent.preferredLocales : speechLocales(for: persona.languageCode)
        let wanted: AVSpeechSynthesisVoiceGender = persona.accent.gender == .male ? .male : .female
        let approximate = voice.language != locales.first || voice.gender != wanted || (persona.usesAccent && persona.accent.isApproximated)
        let quality = Quality(voice.quality)
        return Summary(name: voice.name, quality: quality, isApproximate: approximate, canImprove: quality < .enhanced)
    }
}
