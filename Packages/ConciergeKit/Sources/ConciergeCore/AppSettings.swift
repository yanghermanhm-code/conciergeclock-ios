import Foundation

/// Light / dark appearance.
public enum ThemePreference: String, Codable, Sendable, CaseIterable, Hashable {
    case system, light, dark
}

/// The Home Screen icon. On iOS 18+ the default icon also has dark and tinted variants.
public enum AppIconChoice: String, Codable, Sendable, CaseIterable, Hashable {
    case dark, light

    /// Name of the alternate icon in the asset catalog (nil = primary icon).
    public var alternateIconName: String? {
        switch self {
        case .dark: nil
        case .light: "AppIcon-Light"
        }
    }
}

/// Which offline AI model to use. Raw values are stored, so never rename a case. Same values
/// as PrepPilot's `LocalModelChoice`.
public enum LocalModelChoice: String, Codable, Sendable, CaseIterable, Hashable {
    /// The best model this iPhone runs well (E4B with 8 GB of memory, E2B with 6 GB).
    case automatic
    case gemma4E2B
    case gemma4E4B

    /// The catalog id of the chosen model (nil = automatic).
    public var modelID: String? {
        switch self {
        case .automatic: nil
        case .gemma4E2B: "gemma-4-e2b-it"
        case .gemma4E4B: "gemma-4-e4b-it"
        }
    }
}

/// User preferences. Stored as one JSON document; decoding is forgiving so settings written
/// by older or newer versions always open (missing keys fall back to defaults).
public struct AppSettings: Codable, Hashable, Sendable {
    public var schemaVersion: Int = SchemaVersion.settings

    // Appearance & language
    public var theme: ThemePreference = .system
    /// BCP-47 code of the app's on-screen language, or nil to follow the iPhone's language.
    public var languageCode: String? = nil
    public var appIcon: AppIconChoice = .dark
    public var hapticsEnabled: Bool = true
    public var hasCompletedOnboarding: Bool = false

    // The butler
    public var butlerName: ButlerName = ButlerName()
    /// Default voice: a British gentleman.
    public var voiceAccent: VoiceAccent = .britishMale
    /// Default tone: Professional (crisp, formal, a touch snobbish).
    public var tone: PersonaTone = .professional
    public var briefingLength: BriefingLength = .quick
    /// Spoken language, chosen separately from the on-screen language. English by default.
    public var briefingLanguageCode: String = "en"
    /// Set once the user has read the Unhinged notice.
    public var unhingedAcknowledged: Bool = false
    /// Mild swearing in the Unhinged tone (never slurs or abuse).
    public var allowMildSwearing: Bool = true
    /// Read event titles aloud. Off = "a private event" with time and importance only.
    public var speakEventTitles: Bool = true

    // Snooze
    public var defaultSnoozeMinutes: Int = Snooze.defaultMinutes
    /// Each snooze is phrased a little more firmly.
    public var snoozeEscalation: Bool = true
    /// Most snoozes per alarm (nil = no limit). Alarms can override it.
    public var snoozeLimit: Int? = nil

    // Mornings
    /// "Are you really up?" a few minutes after a voice dismissal.
    public var awakeCheckEnabled: Bool = true
    public var awakeCheckDelayMinutes: Int = 3
    /// A short spoken run-through of tomorrow when Nightstand Mode starts.
    public var bedtimePreviewEnabled: Bool = true
    /// In Nightstand Mode, brighten the screen slowly before the alarm.
    public var sunriseEnabled: Bool = true
    public var sunriseMinutes: Int = 15
    /// Offer an alarm time from the first event of the day and the time needed to get ready.
    public var suggestAlarmFromCalendar: Bool = true
    public var getReadyMinutes: Int = 90
    /// Words in a calendar event title that mark a day off (holidays always count).
    public var dayOffKeywords: [String] = AppSettings.defaultDayOffKeywords
    /// Read sleep from Apple Health (opt-in, read-only) for Trends.
    public var healthSleepEnabled: Bool = false
    public var wakeScoreRules: WakeScoreRules = .default

    // Calendars & Reminders (read on the iPhone from every account in iOS Settings: iCloud,
    // Google, Outlook / Exchange / Microsoft 365, Yahoo, subscribed calendars)
    /// Calendars left out of briefings and day-off checks (EventKit identifiers, this iPhone).
    public var excludedCalendarIDs: [String] = []
    /// Reminder lists left out of briefings.
    public var excludedReminderListIDs: [String] = []

    // Offline AI (Gemma) — same options as PrepPilot and FocusFound
    public var useOfflineAI: Bool = true
    public var localModel: LocalModelChoice = .automatic
    /// Download the model on Wi-Fi only (it is several GB).
    public var modelDownloadWiFiOnly: Bool = true

    // Backups
    public var lastBackupAt: Date? = nil
    /// Save a backup to the chosen folder automatically (at most once a day).
    public var autoBackupEnabled: Bool = false
    public var lastAutoBackupAt: Date? = nil

    public init() {}

    public static let `default` = AppSettings()

    public static let defaultDayOffKeywords = ["Vacation", "Holiday", "Day off", "PTO", "Out of office", "OOO"]

    /// The persona for an alarm (its overrides) or for an on-demand briefing (`alarm` nil).
    public func persona(for alarm: Alarm? = nil) -> Persona {
        Persona(
            name: butlerName,
            accent: alarm?.accentOverride ?? voiceAccent,
            tone: alarm?.toneOverride ?? tone,
            length: alarm?.lengthOverride ?? briefingLength,
            languageCode: briefingLanguageCode,
            allowMildSwearing: allowMildSwearing
        )
    }

    /// The snooze length for `alarm` (its own, or the default).
    public func snoozeMinutes(for alarm: Alarm?) -> Int {
        alarm?.snoozeMinutes ?? defaultSnoozeMinutes
    }

    // MARK: Forgiving Codable

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, theme, languageCode, appIcon, hapticsEnabled, hasCompletedOnboarding
        case butlerName, voiceAccent, tone, briefingLength, briefingLanguageCode
        case unhingedAcknowledged, allowMildSwearing, speakEventTitles
        case defaultSnoozeMinutes, snoozeEscalation, snoozeLimit
        case awakeCheckEnabled, awakeCheckDelayMinutes, bedtimePreviewEnabled, sunriseEnabled, sunriseMinutes
        case suggestAlarmFromCalendar, getReadyMinutes, dayOffKeywords, healthSleepEnabled, wakeScoreRules
        case excludedCalendarIDs, excludedReminderListIDs
        case useOfflineAI, localModel, modelDownloadWiFiOnly
        case lastBackupAt, autoBackupEnabled, lastAutoBackupAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        schemaVersion = SchemaVersion.settings
        theme = c.value(.theme, default: d.theme)
        languageCode = c.value(.languageCode, default: d.languageCode)
        appIcon = c.value(.appIcon, default: d.appIcon)
        hapticsEnabled = c.value(.hapticsEnabled, default: d.hapticsEnabled)
        hasCompletedOnboarding = c.value(.hasCompletedOnboarding, default: d.hasCompletedOnboarding)
        butlerName = c.value(.butlerName, default: d.butlerName).sanitized
        voiceAccent = c.value(.voiceAccent, default: d.voiceAccent)
        tone = c.value(.tone, default: d.tone)
        briefingLength = c.value(.briefingLength, default: d.briefingLength)
        briefingLanguageCode = c.value(.briefingLanguageCode, default: d.briefingLanguageCode)
        unhingedAcknowledged = c.value(.unhingedAcknowledged, default: d.unhingedAcknowledged)
        allowMildSwearing = c.value(.allowMildSwearing, default: d.allowMildSwearing)
        speakEventTitles = c.value(.speakEventTitles, default: d.speakEventTitles)
        defaultSnoozeMinutes = c.value(.defaultSnoozeMinutes, default: d.defaultSnoozeMinutes).clamped(to: Snooze.minuteRange)
        snoozeEscalation = c.value(.snoozeEscalation, default: d.snoozeEscalation)
        snoozeLimit = c.value(.snoozeLimit, default: d.snoozeLimit).map { $0.clamped(to: 0...20) }
        awakeCheckEnabled = c.value(.awakeCheckEnabled, default: d.awakeCheckEnabled)
        awakeCheckDelayMinutes = c.value(.awakeCheckDelayMinutes, default: d.awakeCheckDelayMinutes).clamped(to: 1...15)
        bedtimePreviewEnabled = c.value(.bedtimePreviewEnabled, default: d.bedtimePreviewEnabled)
        sunriseEnabled = c.value(.sunriseEnabled, default: d.sunriseEnabled)
        sunriseMinutes = c.value(.sunriseMinutes, default: d.sunriseMinutes).clamped(to: 5...60)
        suggestAlarmFromCalendar = c.value(.suggestAlarmFromCalendar, default: d.suggestAlarmFromCalendar)
        getReadyMinutes = c.value(.getReadyMinutes, default: d.getReadyMinutes).clamped(to: 10...240)
        dayOffKeywords = c.value(.dayOffKeywords, default: d.dayOffKeywords)
        healthSleepEnabled = c.value(.healthSleepEnabled, default: d.healthSleepEnabled)
        wakeScoreRules = c.value(.wakeScoreRules, default: d.wakeScoreRules).clamped
        excludedCalendarIDs = c.value(.excludedCalendarIDs, default: d.excludedCalendarIDs)
        excludedReminderListIDs = c.value(.excludedReminderListIDs, default: d.excludedReminderListIDs)
        useOfflineAI = c.value(.useOfflineAI, default: d.useOfflineAI)
        localModel = c.value(.localModel, default: d.localModel)
        modelDownloadWiFiOnly = c.value(.modelDownloadWiFiOnly, default: d.modelDownloadWiFiOnly)
        lastBackupAt = c.value(.lastBackupAt, default: d.lastBackupAt)
        autoBackupEnabled = c.value(.autoBackupEnabled, default: d.autoBackupEnabled)
        lastAutoBackupAt = c.value(.lastAutoBackupAt, default: d.lastAutoBackupAt)
    }
}
