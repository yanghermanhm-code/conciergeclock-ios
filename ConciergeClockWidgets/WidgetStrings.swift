import Foundation
import ConciergeCore

/// Translations for the widget, following ConciergeClock's language setting when the app has set
/// one (otherwise the iPhone's language).
struct WidgetStrings {
    let bundle: Bundle
    let locale: Locale

    init(languageCode: String?) {
        if let code = languageCode, let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) {
            self.bundle = bundle
            self.locale = Locale(identifier: code)
        } else {
            self.bundle = .main
            self.locale = .current
        }
    }

    subscript(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    func callAsFunction(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: self[key], locale: locale, arguments: arguments)
    }
}
