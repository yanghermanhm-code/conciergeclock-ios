import Foundation
import SwiftUI

/// Languages Concierge Clock ships with (the same 11 as PrepPilot, FocusFound and FotoPhilter). Raw values are the
/// `.lproj` folder names.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case chineseSimplified = "zh-Hans"
    case hindi = "hi"
    case urdu = "ur"
    case arabic = "ar"
    case hebrew = "he"
    case portuguese = "pt-BR"
    case bengali = "bn"
    case indonesian = "id"

    var id: String { rawValue }

    /// Name shown in the picker, written in the language itself.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .french: "Français"
        case .spanish: "Español"
        case .chineseSimplified: "简体中文"
        case .hindi: "हिन्दी"
        case .urdu: "اردو"
        case .arabic: "العربية"
        case .hebrew: "עברית"
        case .portuguese: "Português (Brasil)"
        case .bengali: "বাংলা"
        case .indonesian: "Bahasa Indonesia"
        }
    }

    var isRightToLeft: Bool {
        switch self {
        case .arabic, .hebrew, .urdu: true
        default: false
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    /// The best supported match for the iPhone's own language settings.
    static var systemDefault: AppLanguage {
        for identifier in Bundle.main.preferredLocalizations + Locale.preferredLanguages {
            if let match = match(identifier) { return match }
        }
        return .english
    }

    /// Maps codes such as "fr-CA", "zh-Hans-CN", "pt-PT" or "in" to a supported language.
    static func match(_ identifier: String) -> AppLanguage? {
        if let exact = AppLanguage(rawValue: identifier) { return exact }
        let lowered = identifier.lowercased()
        if lowered.hasPrefix("zh") { return .chineseSimplified }
        if lowered.hasPrefix("pt") { return .portuguese }
        if lowered == "in" || lowered.hasPrefix("in-") { return .indonesian } // legacy code
        if lowered == "iw" || lowered.hasPrefix("iw-") { return .hebrew } // legacy code
        let base = lowered.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? lowered
        return AppLanguage(rawValue: base)
    }

    /// The language selected in settings (`nil` = follow the iPhone).
    static func resolve(code: String?) -> AppLanguage {
        code.flatMap(AppLanguage.init(rawValue:)) ?? systemDefault
    }
}

/// Looks up translated strings for one language. Injected into the SwiftUI environment,
/// so changing the language in Settings re-renders the whole app instantly — no restart.
///
/// Usage in a view:
/// ```swift
/// @Environment(\.l10n) private var l10n
/// Text(l10n["tab.alarms"])
/// Text(l10n("alarms.count", 3))   // with format arguments
/// ```
struct Localizer: Equatable {
    let language: AppLanguage
    private let bundle: Bundle

    init(language: AppLanguage) {
        self.language = language
        let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj")
        self.bundle = path.flatMap(Bundle.init(path:)) ?? .main
    }

    var locale: Locale { language.locale }
    var layoutDirection: LayoutDirection { language.isRightToLeft ? .rightToLeft : .leftToRight }

    /// Translated string for `key`. Falls back to English, then to the key itself.
    subscript(_ key: String) -> String {
        let value = bundle.localizedString(forKey: key, value: Self.missing, table: nil)
        if value != Self.missing { return value }
        return Self.english.localizedString(forKey: key, value: key, table: nil)
    }

    /// Translated format string with arguments, e.g. `l10n("alarms.count", 3)`.
    func callAsFunction(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: self[key], locale: locale, arguments: arguments)
    }

    /// Localized short time, e.g. "3:45 PM" / "15:45".
    func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    /// Localized medium date and short time, e.g. "May 1, 2026 at 10:30".
    func dateTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }

    /// Localized file size, e.g. "12.4 MB".
    func bytes(_ count: Int64) -> String {
        count.formatted(ByteCountFormatStyle(style: .file).locale(locale))
    }

    /// Localized whole number with grouping, e.g. "4,032".
    func number(_ value: Int) -> String {
        value.formatted(IntegerFormatStyle<Int>().locale(locale))
    }

    /// Localized decimal with up to `digits` fraction digits.
    func decimal(_ value: Double, digits: Int = 1) -> String {
        value.formatted(FloatingPointFormatStyle<Double>().precision(.fractionLength(0...digits)).locale(locale))
    }

    static func == (lhs: Localizer, rhs: Localizer) -> Bool {
        lhs.language == rhs.language
    }

    private static let missing = "\u{1}__missing__"
    private static let english: Bundle = {
        Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }()
}

private struct LocalizerKey: EnvironmentKey {
    static let defaultValue = Localizer(language: .systemDefault)
}

extension EnvironmentValues {
    var l10n: Localizer {
        get { self[LocalizerKey.self] }
        set { self[LocalizerKey.self] = newValue }
    }
}

extension View {
    /// Applies a language to a view tree: strings, number/date formatting and RTL layout.
    func localized(_ localizer: Localizer) -> some View {
        environment(\.l10n, localizer)
            .environment(\.locale, localizer.locale)
            .environment(\.layoutDirection, localizer.layoutDirection)
    }
}
