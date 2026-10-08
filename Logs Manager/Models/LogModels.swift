import Foundation
import SwiftUI

enum LogLevel: String, CaseIterable, Identifiable, Sendable {
    case `default` = "Default"
    case error = "Error"
    case fault = "Fault"
    case info = "Info"
    case debug = "Debug"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: L10n.ru("Событие", en: "Event")
        case .error: L10n.ru("Ошибка", en: "Error")
        case .fault: L10n.ru("Критический сбой", en: "Critical Failure")
        case .info: L10n.ru("Информация", en: "Info")
        case .debug: L10n.ru("Отладка", en: "Debug")
        }
    }

    var iconName: String {
        switch self {
        case .default: "info.circle"
        case .error: "exclamationmark.triangle.fill"
        case .fault: "xmark.octagon.fill"
        case .info: "info"
        case .debug: "ladybug"
        }
    }

    var tint: Color {
        switch self {
        case .default: .primary
        case .error: .orange
        case .fault: .red
        case .info: .secondary
        case .debug: .purple
        }
    }

    /// Уровни, которые по умолчанию выводятся пользователю.
    var isVisibleByDefault: Bool {
        self == .default || self == .error || self == .fault
    }
}

struct LogEntry: Identifiable, Hashable, Sendable {
    let id: String
    let timestamp: Date
    let messageType: LogLevel
    let subsystem: String
    let category: String
    let processName: String
    let processID: Int?
    let threadID: Int?
    let eventMessage: String
    let formatString: String

    var isDangerous: Bool {
        let haystack = [
            eventMessage,
            formatString,
            processName,
            subsystem,
            category
        ].joined(separator: " ")
        let lowercased = haystack.lowercased()
        return Self.dangerousPatterns.contains { lowercased.contains($0) }
    }

    private static let dangerousPatterns = [
        "panic",
        "crash",
        "kernel",
        "sigabrt",
        "memory pressure"
    ]

    nonisolated static func parse(_ dictionary: [String: Any]) -> LogEntry? {
        guard let timestampString = dictionary["timestamp"] as? String,
              let timestamp = LogEntry.timestampFormatter.date(from: timestampString) else {
            return nil
        }

        let rawLevel = dictionary["messageType"] as? String ?? "Default"
        let level = LogLevel(rawValue: rawLevel) ?? .default

        let subsystem = dictionary["subsystem"] as? String ?? "com.apple.system"
        let category = dictionary["category"] as? String ?? "general"
        let eventMessage = dictionary["eventMessage"] as? String ?? ""
        let formatString = dictionary["formatString"] as? String ?? eventMessage

        let processPath = dictionary["processImagePath"] as? String
        let senderPath = dictionary["senderImagePath"] as? String
        let processName = Self.processName(from: processPath ?? senderPath)

        let processID = (dictionary["processID"] as? NSNumber)?.intValue
        let threadID = (dictionary["threadID"] as? NSNumber)?.intValue
        let traceID = (dictionary["traceID"] as? NSNumber)?.stringValue ?? UUID().uuidString

        let stableID = "\(timestamp.timeIntervalSince1970)-\(subsystem)-\(category)-\(processID ?? 0)-\(threadID ?? 0)-\(traceID)"

        return LogEntry(
            id: stableID,
            timestamp: timestamp,
            messageType: level,
            subsystem: subsystem,
            category: category,
            processName: processName,
            processID: processID,
            threadID: threadID,
            eventMessage: eventMessage,
            formatString: formatString
        )
    }

    nonisolated private static func processName(from path: String?) -> String {
        guard let path, !path.isEmpty else { return L10n.ru("Система", en: "System") }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    nonisolated static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZZZZZ"
        return formatter
    }()
}

struct LogGroup: Identifiable, Hashable {
    let id: String
    let subsystem: String
    let category: String
    let entries: [LogEntry]

    var latestTimestamp: Date {
        entries.map(\.timestamp).max() ?? .distantPast
    }
}

enum LogTab: String, CaseIterable, Identifiable {
    case all
    case errors
    case critical
    case dangerousPatterns
    case appLogs
    case taskManager
    case timeTravel
    case recommendations
    case about
    case stressTest
    case processes
    case security
    case network
    case power
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L10n.ru("Все логи", en: "All Logs")
        case .errors: L10n.ru("Ошибки", en: "Errors")
        case .critical: L10n.ru("Критические сбои", en: "Critical")
        case .dangerousPatterns: L10n.ru("Опасные паттерны логов", en: "Dangerous Patterns")
        case .appLogs: L10n.ru("Мониторинг приложений", en: "App Monitoring")
        case .taskManager: L10n.ru("Диспетчер задач", en: "Task Manager")
        case .timeTravel: L10n.ru("Путешествие во времени", en: "Time Travel")
        case .recommendations: L10n.ru("Рекомендации", en: "Recommendations")
        case .about: L10n.ru("О приложении", en: "About")
        case .stressTest: L10n.ru("Стресс-тест", en: "Stress Test")
        case .processes: L10n.ru("Процессы", en: "Processes")
        case .security: L10n.ru("Безопасность", en: "Security")
        case .network: L10n.ru("Сеть", en: "Network")
        case .power: L10n.ru("Питание", en: "Power")
        case .settings: L10n.ru("Настройки", en: "Settings")
        }
    }

    var iconName: String {
        switch self {
        case .all: "tray.full.fill"
        case .errors: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        case .dangerousPatterns: "flame.fill"
        case .appLogs: "app.badge"
        case .taskManager: "gauge"
        case .timeTravel: "clock.arrow.circlepath"
        case .recommendations: "sparkles"
        case .about: "info.circle"
        case .stressTest: "flame"
        case .processes: "cpu"
        case .security: "lock.shield.fill"
        case .network: "network"
        case .power: "bolt.fill"
        case .settings: "gearshape.fill"
        }
    }

    var annotation: String {
        switch self {
        case .all: L10n.ru("Здесь собраны все доступные записи системного журнала.", en: "All available system log entries.")
        case .errors: L10n.ru("Только события уровня «Ошибка».", en: "Error-level events only.")
        case .critical: L10n.ru("Критические сбои и аварийные завершения.", en: "Critical failures and crashes.")
        case .dangerousPatterns: L10n.ru("Паники, краши, сигналы ядра, SIGABRT и memory pressure.", en: "Panics, crashes, kernel signals, SIGABRT, and memory pressure.")
        case .appLogs: L10n.ru("Логи и нагрузка конкретного запущенного приложения.", en: "Logs and load of a specific running app.")
        case .taskManager: L10n.ru("Нагрузка ЦПУ, ГПУ и ОЗУ по процессам, а также запущенные программы.", en: "CPU, GPU, and RAM load per process, plus running apps.")
        case .timeTravel: L10n.ru("Просмотр логов и состояния системы на выбранный момент в прошлом.", en: "View logs and system state at a selected past moment.")
        case .recommendations: L10n.ru("Отчёт и рекомендации по системе на основе DeepSeek.", en: "System report and recommendations powered by DeepSeek.")
        case .about: L10n.ru("Информация о приложении и поддержка разработчика.", en: "App information and developer support.")
        case .stressTest: L10n.ru("Ручной стресс-тест CPU и GPU с мониторингом нагрузки.", en: "Manual CPU and GPU stress test with load monitoring.")
        case .processes: L10n.ru("События запуска, завершения и жизненного цикла процессов.", en: "Process launch, exit, and lifecycle events.")
        case .security: L10n.ru("События безопасности, аутентификации и приватности.", en: "Security, authentication, and privacy events.")
        case .network: L10n.ru("Сетевые подключения, Wi-Fi, Bluetooth и DNS.", en: "Network connections, Wi-Fi, Bluetooth, and DNS.")
        case .power: L10n.ru("Энергопотребление, батарея, температура и питание.", en: "Energy, battery, thermal, and power events.")
        case .settings: L10n.ru("Общие настройки приложения.", en: "General application settings.")
        }
    }
}

enum LogSearchScope: String, CaseIterable, Identifiable {
    case process
    case title

    var id: String { rawValue }

    var title: String {
        switch self {
        case .process: L10n.ru("Название процесса", en: "Process Name")
        case .title: L10n.ru("Содержит в названии", en: "Contains in Title")
        }
    }
}
