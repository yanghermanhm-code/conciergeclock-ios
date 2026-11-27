import ConciergeCore
import Foundation

/// App-specific translations for core types (ConciergeCore stays language-neutral).
extension Localizer {
    func accentName(_ accent: VoiceAccent) -> String {
        switch accent {
        case .canadianMale: self["accent.canadianMale"]
        case .canadianFemale: self["accent.canadianFemale"]
        case .southernMale: self["accent.southernMale"]
        case .southernFemale: self["accent.southernFemale"]
        case .britishMale: self["accent.britishMale"]
        case .britishFemale: self["accent.britishFemale"]
        case .indianMale: self["accent.indianMale"]
        case .indianFemale: self["accent.indianFemale"]
        }
    }

    func toneName(_ tone: PersonaTone) -> String {
        switch tone {
        case .moderate: self["tone.moderate"]
        case .professional: self["tone.professional"]
        case .child: self["tone.child"]
        case .unhinged: self["tone.unhinged"]
        }
    }

    func toneHint(_ tone: PersonaTone) -> String {
        switch tone {
        case .moderate: self["tone.moderate.hint"]
        case .professional: self["tone.professional.hint"]
        case .child: self["tone.child.hint"]
        case .unhinged: self["tone.unhinged.hint"]
        }
    }

    /// A sample line in each tone, shown under the tone picker (the spoken versions, in every
    /// briefing language, arrive with the briefing in Phase 2).
    func toneSample(_ tone: PersonaTone, name: String) -> String {
        switch tone {
        case .moderate: self("tone.moderate.sample", name)
        case .professional: self("tone.professional.sample", name)
        case .child: self("tone.child.sample", name)
        case .unhinged: self("tone.unhinged.sample", name)
        }
    }

    func lengthName(_ length: BriefingLength) -> String {
        switch length {
        case .quick: self["length.quick"]
        case .standard: self["length.standard"]
        case .full: self["length.full"]
        }
    }

    func lengthHint(_ length: BriefingLength) -> String {
        switch length {
        case .quick: self["length.quick.hint"]
        case .standard: self["length.standard.hint"]
        case .full: self["length.full.hint"]
        }
    }

    func minutesText(_ minutes: Int) -> String {
        self("minutes.count", minutes)
    }

    func languageName(code: String) -> String {
        if let language = AppLanguage(rawValue: code) { return language.nativeName }
        return locale.localizedString(forIdentifier: code) ?? code
    }

    /// File sizes for the offline AI screens ("2.6 GB").
    func byteText(_ bytes: Int64) -> String {
        self.bytes(bytes)
    }

    /// "Mon Tue Wed", "Every day", "Weekdays", "Weekends" or "Once".
    func repeatText(_ days: Set<Weekday>) -> String {
        if days.isEmpty { return self["repeat.once"] }
        if days.count == 7 { return self["repeat.everyDay"] }
        if days == Weekdays.workWeek { return self["repeat.weekdays"] }
        if days == Weekdays.weekend { return self["repeat.weekends"] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.shortWeekdaySymbols
        return Weekdays.all.filter { days.contains($0) }.map { symbols[$0 - 1] }.joined(separator: " ")
    }
}
