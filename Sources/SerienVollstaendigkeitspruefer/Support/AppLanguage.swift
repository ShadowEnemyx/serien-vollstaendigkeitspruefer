import Foundation

/// Die Sprachwahl gehört zur App statt zu den Systemeinstellungen, damit sie
/// jederzeit direkt im Fenster zwischen Deutsch und Englisch wechseln kann.
enum AppLanguage: String, CaseIterable, Identifiable {
    case german = "de"
    case english = "en"

    static let storageKey = "appLanguage"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var displayName: String { self == .german ? "Deutsch" : "English" }

    static var current: AppLanguage {
        guard let value = UserDefaults.standard.string(forKey: storageKey),
              let language = AppLanguage(rawValue: value) else {
            return .german
        }
        return language
    }

    func text(_ german: String, _ english: String) -> String {
        self == .german ? german : english
    }
}

func localized(_ german: String, _ english: String) -> String {
    AppLanguage.current.text(german, english)
}
