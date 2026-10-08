import SwiftUI
import Combine

enum AppBackground: String, CaseIterable, Identifiable {
    case standard
    case aurora
    case ocean
    case orchid
    case meadow
    case calmDusk
    case softSlate
    case liquidSage
    case liquidDusk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: L10n.ru("Стандартный", en: "Standard")
        case .aurora: L10n.ru("Северное сияние", en: "Aurora")
        case .ocean: L10n.ru("Глубокий океан", en: "Deep Ocean")
        case .orchid: L10n.ru("Пурпурная орхидея", en: "Purple Orchid")
        case .meadow: L10n.ru("Утренний луг", en: "Morning Meadow")
        case .calmDusk: L10n.ru("Спокойные сумерки", en: "Calm Dusk")
        case .softSlate: L10n.ru("Мягкий графит", en: "Soft Graphite")
        case .liquidSage: L10n.ru("Шалфей", en: "Sage")
        case .liquidDusk: L10n.ru("Сумерки", en: "Dusk")
        }
    }

    var isCustom: Bool { self != .standard }

    @ViewBuilder
    var backgroundView: some View {
        switch self {
        case .standard:
            EmptyView()
        case .aurora:
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.07, blue: 0.18),
                    Color(red: 0.08, green: 0.35, blue: 0.42),
                    Color(red: 0.23, green: 0.62, blue: 0.48)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        case .ocean:
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.20, blue: 0.29),
                    Color(red: 0.22, green: 0.36, blue: 0.46),
                    Color(red: 0.34, green: 0.52, blue: 0.59)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        case .orchid:
            LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.20, blue: 0.29),
                    Color(red: 0.38, green: 0.31, blue: 0.43),
                    Color(red: 0.55, green: 0.46, blue: 0.58)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        case .meadow:
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.20, blue: 0.16),
                    Color(red: 0.21, green: 0.32, blue: 0.25),
                    Color(red: 0.31, green: 0.45, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        case .calmDusk:
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.13, blue: 0.20),
                    Color(red: 0.24, green: 0.22, blue: 0.30),
                    Color(red: 0.38, green: 0.31, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        case .softSlate:
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.18, blue: 0.21),
                    Color(red: 0.25, green: 0.29, blue: 0.31),
                    Color(red: 0.36, green: 0.40, blue: 0.40)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        case .liquidSage:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.20, blue: 0.18),
                        Color(red: 0.20, green: 0.34, blue: 0.28),
                        Color(red: 0.31, green: 0.48, blue: 0.38)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 8,
                    endRadius: 520
                )
            }
            .ignoresSafeArea()
        case .liquidDusk:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.14, blue: 0.22),
                        Color(red: 0.26, green: 0.23, blue: 0.34),
                        Color(red: 0.42, green: 0.34, blue: 0.45)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 12,
                    endRadius: 560
                )
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    var previewView: some View {
        switch self {
        case .standard:
            Color.gray.opacity(0.18)
        case .aurora:
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.07, blue: 0.18),
                    Color(red: 0.08, green: 0.35, blue: 0.42),
                    Color(red: 0.23, green: 0.62, blue: 0.48)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ocean:
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.20, blue: 0.29),
                    Color(red: 0.22, green: 0.36, blue: 0.46),
                    Color(red: 0.34, green: 0.52, blue: 0.59)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .orchid:
            LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.20, blue: 0.29),
                    Color(red: 0.38, green: 0.31, blue: 0.43),
                    Color(red: 0.55, green: 0.46, blue: 0.58)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .meadow:
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.20, blue: 0.16),
                    Color(red: 0.21, green: 0.32, blue: 0.25),
                    Color(red: 0.31, green: 0.45, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .calmDusk:
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.13, blue: 0.20),
                    Color(red: 0.24, green: 0.22, blue: 0.30),
                    Color(red: 0.38, green: 0.31, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .softSlate:
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.18, blue: 0.21),
                    Color(red: 0.25, green: 0.29, blue: 0.31),
                    Color(red: 0.36, green: 0.40, blue: 0.40)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .liquidSage:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.20, blue: 0.18),
                        Color(red: 0.20, green: 0.34, blue: 0.28),
                        Color(red: 0.31, green: 0.48, blue: 0.38)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color.white.opacity(0.10), .clear],
                    center: .topLeading,
                    startRadius: 4,
                    endRadius: 120
                )
            }
        case .liquidDusk:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.14, blue: 0.22),
                        Color(red: 0.26, green: 0.23, blue: 0.34),
                        Color(red: 0.42, green: 0.34, blue: 0.45)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color.white.opacity(0.08), .clear],
                    center: .top,
                    startRadius: 5,
                    endRadius: 130
                )
            }
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var showDebugInfo: Bool {
        didSet {
            UserDefaults.standard.set(showDebugInfo, forKey: "showDebugInfo")
        }
    }

    @Published var windowMinutes: Int {
        didSet {
            UserDefaults.standard.set(windowMinutes, forKey: "windowMinutes")
        }
    }

    @Published var background: AppBackground {
        didSet {
            UserDefaults.standard.set(background.rawValue, forKey: "appBackground")
        }
    }

    @Published var taskManagerLoadSettings: LoadRecordingSettings {
        didSet {
            Self.save(settings: taskManagerLoadSettings, forKey: "taskManagerLoadSettings")
        }
    }

    @Published var appLogsLoadSettings: LoadRecordingSettings {
        didSet {
            Self.save(settings: appLogsLoadSettings, forKey: "appLogsLoadSettings")
        }
    }

    @Published var sidebarVisibleTabs: [LogTab] {
        didSet {
            UserDefaults.standard.set(sidebarVisibleTabs.map(\.rawValue), forKey: "sidebarVisibleTabs")
        }
    }

    @Published var sidebarHiddenTabs: [LogTab] {
        didSet {
            UserDefaults.standard.set(sidebarHiddenTabs.map(\.rawValue), forKey: "sidebarHiddenTabs")
        }
    }

    @Published var backgroundMonitoringEnabled: Bool {
        didSet {
            UserDefaults.standard.set(backgroundMonitoringEnabled, forKey: "backgroundMonitoringEnabled")
        }
    }

    @Published var notifyFault: Bool {
        didSet {
            UserDefaults.standard.set(notifyFault, forKey: "notifyFault")
        }
    }

    @Published var notifyError: Bool {
        didSet {
            UserDefaults.standard.set(notifyError, forKey: "notifyError")
        }
    }

    @Published var notifyDefault: Bool {
        didSet {
            UserDefaults.standard.set(notifyDefault, forKey: "notifyDefault")
        }
    }

    @Published var showSectionAnnotations: Bool {
        didSet {
            UserDefaults.standard.set(showSectionAnnotations, forKey: "showSectionAnnotations")
        }
    }

    @Published var highCPUNotificationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(highCPUNotificationEnabled, forKey: "highCPUNotificationEnabled")
        }
    }

    @Published var loadHistoryRetentionDays: Int {
        didSet {
            UserDefaults.standard.set(loadHistoryRetentionDays, forKey: "loadHistoryRetentionDays")
        }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLoginEnabled, forKey: "launchAtLoginEnabled")
        }
    }

    @Published var deepSeekAPIKey: String {
        didSet {
            if deepSeekAPIKey.isEmpty {
                KeychainStore.delete(account: "deepseek-api-key")
            } else {
                KeychainStore.save(deepSeekAPIKey, account: "deepseek-api-key")
            }
        }
    }

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            AppLanguage.setOverride(language)
        }
    }

    var notificationLevels: Set<LogLevel> {
        var levels: Set<LogLevel> = []
        if notifyFault { levels.insert(.fault) }
        if notifyError { levels.insert(.error) }
        if notifyDefault { levels.insert(.default) }
        return levels
    }

    init() {
        showDebugInfo = UserDefaults.standard.object(forKey: "showDebugInfo") as? Bool ?? false
        windowMinutes = UserDefaults.standard.object(forKey: "windowMinutes") as? Int ?? 15
        let savedBackground = UserDefaults.standard.string(forKey: "appBackground")
        background = savedBackground.flatMap(AppBackground.init(rawValue:)) ?? .standard
        taskManagerLoadSettings = Self.loadSettings(forKey: "taskManagerLoadSettings")
        appLogsLoadSettings = Self.loadSettings(forKey: "appLogsLoadSettings")
        let hiddenTabs = Self.loadTabs(forKey: "sidebarHiddenTabs", fallback: [])
        sidebarHiddenTabs = hiddenTabs
        sidebarVisibleTabs = Self.loadTabs(
            forKey: "sidebarVisibleTabs",
            fallback: Self.defaultSidebarTabs,
            excludedTabs: hiddenTabs
        )
        backgroundMonitoringEnabled = UserDefaults.standard.object(forKey: "backgroundMonitoringEnabled") as? Bool ?? false
        notifyFault = UserDefaults.standard.object(forKey: "notifyFault") as? Bool ?? true
        notifyError = UserDefaults.standard.object(forKey: "notifyError") as? Bool ?? true
        notifyDefault = UserDefaults.standard.object(forKey: "notifyDefault") as? Bool ?? false
        showSectionAnnotations = UserDefaults.standard.object(forKey: "showSectionAnnotations") as? Bool ?? true
        highCPUNotificationEnabled = UserDefaults.standard.object(forKey: "highCPUNotificationEnabled") as? Bool ?? false
        loadHistoryRetentionDays = UserDefaults.standard.object(forKey: "loadHistoryRetentionDays") as? Int ?? 7
        launchAtLoginEnabled = UserDefaults.standard.object(forKey: "launchAtLoginEnabled") as? Bool ?? false
        deepSeekAPIKey = KeychainStore.load(account: "deepseek-api-key") ?? ""
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        language = savedLanguage.flatMap(AppLanguage.init(rawValue:)) ?? .system
        AppLanguage.setOverride(language)
    }

    private static func save(settings: LoadRecordingSettings, forKey key: String) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadSettings(forKey key: String) -> LoadRecordingSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(LoadRecordingSettings.self, from: data) else {
            return LoadRecordingSettings()
        }
        return settings
    }

    private static var defaultSidebarTabs: [LogTab] {
        [.all, .errors, .critical, .dangerousPatterns, .appLogs, .processes, .security, .network, .power, .taskManager, .timeTravel, .recommendations, .about, .stressTest, .settings]
    }

    private static func loadTabs(
        forKey key: String,
        fallback: [LogTab],
        excludedTabs: [LogTab] = []
    ) -> [LogTab] {
        guard let rawValues = UserDefaults.standard.stringArray(forKey: key) else {
            return fallback.filter { !excludedTabs.contains($0) }
        }
        var tabs = rawValues.compactMap(LogTab.init(rawValue:))
        if tabs.isEmpty { tabs = fallback }
        let missing = fallback.filter { !tabs.contains($0) && !excludedTabs.contains($0) }
        return tabs + missing
    }
}
