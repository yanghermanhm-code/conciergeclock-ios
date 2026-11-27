import Foundation

/// The butler's voice: eight accent profiles. Raw values are stored, so never rename a case.
///
/// Each profile maps to the closest voice available on the iPhone (Apple's voices) or in the
/// bundled offline voice engine (Phase 7). There is no true Southern US or Canadian voice
/// anywhere offline today, so those two use the closest North American voice with regional
/// wording and pacing (see docs/DECISIONS.md).
public enum VoiceAccent: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case canadianMale
    case canadianFemale
    case southernMale
    case southernFemale
    case britishMale
    case britishFemale
    case indianMale
    case indianFemale

    public var id: String { rawValue }

    public enum Gender: String, Codable, Sendable, Hashable {
        case male, female
    }

    public enum Region: String, Codable, Sendable, Hashable, CaseIterable {
        case canadian, southernUS, british, indian
    }

    public var gender: Gender {
        switch self {
        case .canadianMale, .southernMale, .britishMale, .indianMale: .male
        case .canadianFemale, .southernFemale, .britishFemale, .indianFemale: .female
        }
    }

    public var region: Region {
        switch self {
        case .canadianMale, .canadianFemale: .canadian
        case .southernMale, .southernFemale: .southernUS
        case .britishMale, .britishFemale: .british
        case .indianMale, .indianFemale: .indian
        }
    }

    /// The speech locale to look for first, then the fallbacks, best first.
    public var preferredLocales: [String] {
        switch region {
        case .canadian: ["en-CA", "en-US"]
        case .southernUS: ["en-US"]
        case .british: ["en-GB", "en-IE", "en-AU"]
        case .indian: ["en-IN", "hi-IN"]
        }
    }

    /// Whether no voice with this exact accent exists, so the closest voice is used with
    /// regional wording instead.
    public var isApproximated: Bool {
        region == .southernUS || region == .canadian
    }
}

/// How the butler speaks. Raw values are stored, so never rename a case.
public enum PersonaTone: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    /// Natural, clear, helpful concierge.
    case moderate
    /// Crisp, polished, formal — a slightly snobbish British butler. The default.
    case professional
    /// Warm, simple, gentle, easy to follow.
    case child
    /// Blunt, dramatic and impatient, for comedy. Mild swearing only when allowed.
    case unhinged

    public var id: String { rawValue }
}

/// How much the spoken briefing says. Raw values are stored, so never rename a case.
public enum BriefingLength: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    /// The time, the next event and a count of the rest. About 15 seconds.
    case quick
    /// Adds the top three events and due reminders with a one-line summary each.
    case standard
    /// Every event and reminder today, each with its time, summary and importance.
    case full

    public var id: String { rawValue }

    /// Most events and reminders read out individually.
    public var itemLimit: Int {
        switch self {
        case .quick: 1
        case .standard: 3
        case .full: 50
        }
    }
}

/// The butler's names. The formal name is used in the Professional tone, the familiar one in
/// the others; both can be changed in Settings.
public struct ButlerName: Codable, Sendable, Hashable {
    public var formal: String
    public var familiar: String

    public init(formal: String = ButlerName.defaultFormal, familiar: String = ButlerName.defaultFamiliar) {
        self.formal = formal
        self.familiar = familiar
    }

    public static let defaultFormal = "Charles"
    public static let defaultFamiliar = "Charlie"

    /// The name the butler introduces himself with in `tone`. Blank names fall back to the
    /// other name, then to the defaults.
    public func name(for tone: PersonaTone) -> String {
        let formalName = formal.nonBlank ?? familiar.nonBlank ?? Self.defaultFormal
        let familiarName = familiar.nonBlank ?? formal.nonBlank ?? Self.defaultFamiliar
        switch tone {
        case .professional: return formalName
        case .moderate, .child, .unhinged: return familiarName
        }
    }

    /// Names longer than this are cut when saved.
    public static let maxLength = 30

    /// The names trimmed and limited to `maxLength` characters.
    public var sanitized: ButlerName {
        ButlerName(
            formal: String(formal.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxLength)),
            familiar: String(familiar.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxLength))
        )
    }
}

/// Everything that shapes how the butler talks, resolved for one alarm or briefing.
public struct Persona: Codable, Sendable, Hashable {
    public var name: ButlerName
    public var accent: VoiceAccent
    public var tone: PersonaTone
    public var length: BriefingLength
    /// BCP-47 code of the spoken language ("en", "fr", …), independent of the app's language.
    public var languageCode: String
    /// Mild swearing in the Unhinged tone.
    public var allowMildSwearing: Bool

    public init(
        name: ButlerName = ButlerName(), accent: VoiceAccent = .britishMale, tone: PersonaTone = .professional,
        length: BriefingLength = .quick, languageCode: String = "en", allowMildSwearing: Bool = true
    ) {
        self.name = name
        self.accent = accent
        self.tone = tone
        self.length = length
        self.languageCode = languageCode
        self.allowMildSwearing = allowMildSwearing
    }

    /// The name the butler uses right now.
    public var displayName: String { name.name(for: tone) }

    /// Accents only apply to English; other languages use that language's own voices.
    public var usesAccent: Bool { languageCode == "en" }
}
