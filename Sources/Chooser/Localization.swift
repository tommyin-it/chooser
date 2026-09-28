import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en", polish = "pl"
    var name: String { self == .english ? "English" : "Polski" }
}

/// App-owned strings use English by default, independently of the system language.
/// Native system dialogs and browser-supplied profile names retain their own language.
enum Localization {
    static var language = load(from: .standard)
    static func load(from defaults: UserDefaults) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: "appLanguage") ?? "") ?? .english
    }
    static func select(_ language: AppLanguage, defaults: UserDefaults = .standard) {
        defaults.set(language.rawValue, forKey: "appLanguage")
        self.language = language
    }
}

func L(_ english: String, _ polish: String) -> String {
    Localization.language == .polish ? polish : english
}
