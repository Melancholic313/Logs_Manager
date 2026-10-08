import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case russian
    case english

    var id: String { rawValue }

    nonisolated(unsafe) private static var overrideLanguage: AppLanguage?

    nonisolated static func setOverride(_ language: AppLanguage) {
        overrideLanguage = language
    }

    var displayTitle: String {
        switch self {
        case .system: return "System"
        case .russian: return L10n.ru("Русский", en: "Russian")
        case .english: return "English"
        }
    }

    nonisolated static var current: AppLanguage {
        if let overrideLanguage, overrideLanguage != .system {
            return overrideLanguage
        }
        let saved = UserDefaults.standard.string(forKey: "appLanguage")
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
        switch saved {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            if preferred.hasPrefix("ru") {
                return .russian
            }
            return .english
        case .russian, .english:
            return saved
        }
    }
}

enum L10n {
    nonisolated static func ru(_ russian: String, en english: String) -> String {
        AppLanguage.current == .russian ? russian : english
    }
}
