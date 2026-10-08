import Foundation

/// «Словарь», который переводит технические имена и типовые сообщения
/// объединённого журнала macOS в понятный человеку текст.
enum LogHumanizer {
    private static let subsystemNames: [String: String] = [
        "com.apple.securityd": L10n.ru("Безопасность", en: "Security"),
        "com.apple.coreauthd": L10n.ru("Аутентификация", en: "Authentication"),
        "com.apple.accountsd": L10n.ru("Учётные записи", en: "Accounts"),
        "com.apple.runningboard": L10n.ru("Управление процессами", en: "Process Management"),
        "com.apple.launchservices": L10n.ru("Запуск приложений", en: "App Launch"),
        "com.apple.windowserver": L10n.ru("Графика и окна", en: "Graphics and Windows"),
        "com.apple.powerd": L10n.ru("Энергопитание", en: "Power"),
        "com.apple.SystemConfiguration": L10n.ru("Конфигурация системы", en: "System Configuration"),
        "com.apple.cfnetwork": L10n.ru("Сеть", en: "Network"),
        "com.apple.network": L10n.ru("Сеть", en: "Network"),
        "com.apple.wifi": "Wi-Fi",
        "com.apple.WiFi": "Wi-Fi",
        "com.apple.bluetooth": "Bluetooth",
        "com.apple.mDNSResponder": L10n.ru("Служба имён", en: "Name Service"),
        "com.apple.diskmanagement": L10n.ru("Управление дисками", en: "Disk Management"),
        "com.apple.diskarbitrationd": L10n.ru("Подключение дисков", en: "Disk Mounting"),
        "com.apple.fsevents": L10n.ru("Файловая система", en: "File System"),
        "com.apple.filesystems": L10n.ru("Файловые системы", en: "File Systems"),
        "com.apple.apsd": L10n.ru("Push-уведомления", en: "Push Notifications"),
        "com.apple.cloudkit": "iCloud",
        "com.apple.notifyd": L10n.ru("Уведомления", en: "Notifications"),
        "com.apple.symptoms": L10n.ru("Диагностика сети", en: "Network Diagnostics"),
        "com.apple.symptomsd": L10n.ru("Диагностика сети", en: "Network Diagnostics"),
        "com.apple.siri": "Siri",
        "com.apple.siri.client.flow": "Siri",
        "com.apple.chrono": L10n.ru("Время и будильники", en: "Time and Alarms"),
        "com.apple.timed": L10n.ru("Служба времени", en: "Time Service"),
        "com.apple.TCC": L10n.ru("Конфиденциальность", en: "Privacy"),
        "com.apple.sandbox": L10n.ru("Песочница", en: "Sandbox"),
        "com.apple.keychain": L10n.ru("Связка ключей", en: "Keychain"),
        "com.apple.WebKit": "WebKit",
        "com.apple.Safari": "Safari",
        "com.apple.metadata": L10n.ru("Spotlight и поиск", en: "Spotlight and Search"),
        "com.apple.spotlight": L10n.ru("Spotlight и поиск", en: "Spotlight and Search"),
        "com.apple.analyticsd": L10n.ru("Диагностика системы", en: "System Diagnostics"),
        "com.apple.corebrightness": L10n.ru("Яркость экрана", en: "Display Brightness"),
        "com.apple.thermalmonitord": L10n.ru("Температурный контроль", en: "Thermal Control"),
        "com.apple.IOKit": L10n.ru("Драйверы устройств", en: "Device Drivers"),
        "com.apple.coreaudio": L10n.ru("Звук", en: "Audio"),
        "com.apple.audio": L10n.ru("Звук", en: "Audio"),
        "com.apple.coremedia": L10n.ru("Мультимедиа", en: "Media"),
        "com.apple.softwareupdate": L10n.ru("Обновление ПО", en: "Software Update"),
        "com.apple.mobileassetd": L10n.ru("Загрузка системных ресурсов", en: "System Asset Download"),
        "com.apple.logd": L10n.ru("Журналирование", en: "Logging"),
        "com.apple.unifiedlog": L10n.ru("Журналирование", en: "Logging")
    ]

    private static let categoryNames: [String: String] = [
        "assertion": L10n.ru("Права и приоритеты", en: "Rights and Priorities"),
        "process": L10n.ru("Процессы", en: "Processes"),
        "lifecycle": L10n.ru("Жизненный цикл", en: "Lifecycle"),
        "launch": L10n.ru("Запуск", en: "Launch"),
        "exit": L10n.ru("Завершение", en: "Exit"),
        "crash": L10n.ru("Сбои", en: "Crashes"),
        "termination": L10n.ru("Завершение", en: "Termination"),
        "displayState": L10n.ru("Состояние дисплея", en: "Display State"),
        "power": L10n.ru("Питание", en: "Power"),
        "battery": L10n.ru("Батарея", en: "Battery"),
        "energy": L10n.ru("Энергопотребление", en: "Energy"),
        "thermal": L10n.ru("Температура", en: "Thermal"),
        "brightness": L10n.ru("Яркость", en: "Brightness"),
        "wifi": "Wi-Fi",
        "bluetooth": "Bluetooth",
        "network": L10n.ru("Сеть", en: "Network"),
        "connection": L10n.ru("Подключения", en: "Connections"),
        "socket": L10n.ru("Сокеты", en: "Sockets"),
        "dns": "DNS",
        "dnsresolution": L10n.ru("Разрешение имён", en: "Name Resolution"),
        "stack.le": "Bluetooth LE",
        "server.le.scan": L10n.ru("Поиск Bluetooth LE", en: "Bluetooth LE Scan"),
        "security": L10n.ru("Безопасность", en: "Security"),
        "auth": L10n.ru("Аутентификация", en: "Authentication"),
        "keychain": L10n.ru("Связка ключей", en: "Keychain"),
        "tcc": L10n.ru("Конфиденциальность", en: "Privacy"),
        "sandbox": L10n.ru("Песочница", en: "Sandbox"),
        "account": L10n.ru("Учётные записи", en: "Accounts"),
        "privacy": L10n.ru("Конфиденциальность", en: "Privacy"),
        "storage": L10n.ru("Хранилище", en: "Storage"),
        "disk": L10n.ru("Диски", en: "Disks"),
        "filesystem": L10n.ru("Файловая система", en: "File System"),
        "io": L10n.ru("Ввод-вывод", en: "I/O"),
        "iokit": L10n.ru("Драйверы устройств", en: "Device Drivers"),
        "memory": L10n.ru("Память", en: "Memory"),
        "cpu": L10n.ru("Процессор", en: "CPU"),
        "graphics": L10n.ru("Графика", en: "Graphics"),
        "audio": L10n.ru("Звук", en: "Audio"),
        "video": L10n.ru("Видео", en: "Video"),
        "media": L10n.ru("Мультимедиа", en: "Media"),
        "hid": L10n.ru("Устройства ввода", en: "Input Devices"),
        "display": L10n.ru("Дисплей", en: "Display"),
        "notify": L10n.ru("Уведомления", en: "Notifications"),
        "notification": L10n.ru("Уведомления", en: "Notifications"),
        "cloud": L10n.ru("Облако", en: "Cloud"),
        "sync": L10n.ru("Синхронизация", en: "Sync"),
        "reporting": L10n.ru("Отчёты", en: "Reports"),
        "diagnostics": L10n.ru("Диагностика", en: "Diagnostics"),
        "symptoms": L10n.ru("Диагностика", en: "Diagnostics"),
        "analytics": L10n.ru("Аналитика", en: "Analytics"),
        "update": L10n.ru("Обновление", en: "Update"),
        "web": L10n.ru("Веб", en: "Web"),
        "xpc": L10n.ru("Межпроцессное взаимодействие", en: "Interprocess Communication"),
        "kernel": L10n.ru("Ядро", en: "Kernel"),
        "loginwindow": L10n.ru("Экран входа", en: "Login Window"),
        "general": L10n.ru("Общие события", en: "General Events")
    ]

    static func subsystemTitle(_ subsystem: String) -> String {
        if let known = subsystemNames[subsystem] {
            return known
        }
        let short = subsystem
            .replacingOccurrences(of: "com.apple.", with: "")
            .replacingOccurrences(of: "com.", with: "")
        guard !short.isEmpty else { return subsystem }
        return short.prettyCamelCase
    }

    static func categoryTitle(_ category: String) -> String {
        if let known = categoryNames[category.lowercased()] {
            return known
        }
        guard !category.isEmpty else { return L10n.ru("Общие события", en: "General Events") }
        return category.prettyCamelCase
    }

    static func groupTitle(subsystem: String, category: String) -> String {
        "\(subsystemTitle(subsystem)) — \(categoryTitle(category))"
    }

    static func groupIcon(subsystem: String) -> String {
        let value = subsystem.lowercased()
        if value.contains("security") || value.contains("auth") || value.contains("tcc") || value.contains("keychain") {
            return "lock.shield"
        }
        if value.contains("network") || value.contains("wifi") || value.contains("bluetooth") || value.contains("socket") || value.contains("dns") {
            return "network"
        }
        if value.contains("power") || value.contains("battery") || value.contains("energy") || value.contains("thermal") {
            return "bolt"
        }
        if value.contains("runningboard") || value.contains("launchservices") || value.contains("process") || value.contains("windowserver") {
            return "cpu"
        }
        return "rectangle.stack"
    }

    static func timeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.ru("сегодня в \(shortTimeFormatter.string(from: date))", en: "today at \(shortTimeFormatter.string(from: date))")
        }
        if calendar.isDateInYesterday(date) {
            return L10n.ru("вчера в \(shortTimeFormatter.string(from: date))", en: "yesterday at \(shortTimeFormatter.string(from: date))")
        }
        return mediumDateTimeFormatter.string(from: date)
    }

    static func humanizedSentence(for entry: LogEntry) -> String {
        let time = timeLabel(for: entry.timestamp)
        let process = processDescription(entry.processName)

        switch entry.messageType {
        case .fault:
            if hasCrashSignal(in: entry.eventMessage) {
                return L10n.ru("\(time) \(process) аварийно завершил работу\(reasonSuffix(entry.eventMessage))", en: "\(time) \(process) crashed\(reasonSuffix(entry.eventMessage))")
            }
            return L10n.ru("\(time) \(process) сообщил о критическом сбое\(reasonSuffix(entry.eventMessage))", en: "\(time) \(process) reported a critical failure\(reasonSuffix(entry.eventMessage))")
        case .error:
            let lowercased = entry.eventMessage.lowercased()
            if lowercased.contains("timeout") || lowercased.contains("timed out") {
                return L10n.ru("\(time) \(process) не дождался ответа и прекратил операцию из-за тайм-аута", en: "\(time) \(process) timed out and stopped the operation")
            }
            if lowercased.contains("denied") || lowercased.contains("forbidden") || lowercased.contains("not permitted") {
                return L10n.ru("\(time) \(process) получил отказ в выполнении действия", en: "\(time) \(process) was denied")
            }
            if lowercased.contains("not found") || lowercased.contains("no such file") {
                return L10n.ru("\(time) \(process) не смог найти требуемый ресурс", en: "\(time) \(process) could not find the required resource")
            }
            if lowercased.contains("error domain=") || lowercased.contains("nserror") {
                return L10n.ru("\(time) \(process) получил системную ошибку\(reasonSuffix(entry.eventMessage))", en: "\(time) \(process) received a system error\(reasonSuffix(entry.eventMessage))")
            }
            if hasCrashSignal(in: entry.eventMessage) {
                return L10n.ru("\(time) \(process) аварийно завершил работу\(reasonSuffix(entry.eventMessage))", en: "\(time) \(process) crashed\(reasonSuffix(entry.eventMessage))")
            }
            return L10n.ru("\(time) \(process) сообщил об ошибке\(reasonSuffix(entry.eventMessage))", en: "\(time) \(process) reported an error\(reasonSuffix(entry.eventMessage))")
        case .default:
            let lowercased = entry.eventMessage.lowercased()
            if entry.category.lowercased().contains("power")
                || entry.category.lowercased().contains("battery")
                || entry.category.lowercased().contains("energy") {
                return L10n.ru("\(time) \(process) сообщил об изменении состояния питания", en: "\(time) \(process) reported a power-state change")
            }
            if entry.category.lowercased().contains("network")
                || entry.category.lowercased().contains("wifi")
                || entry.category.lowercased().contains("bluetooth") {
                return L10n.ru("\(time) \(process) сообщил о сетевой активности", en: "\(time) \(process) reported network activity")
            }
            if entry.category.lowercased().contains("assertion")
                || entry.subsystem.lowercased().contains("runningboard") {
                return L10n.ru("\(time) \(process) обновил приоритет или права процесса", en: "\(time) \(process) updated process priority or rights")
            }
            if lowercased.contains("launch") || lowercased.contains("started") {
                return L10n.ru("\(time) \(process) был запущен", en: "\(time) \(process) was launched")
            }
            return L10n.ru("\(time) \(process) зарегистрировал служебное событие\(reasonSuffix(entry.eventMessage))", en: "\(time) \(process) registered a service event\(reasonSuffix(entry.eventMessage))")
        case .info, .debug:
            return "\(time) \(process): \(entry.eventMessage)"
        }
    }

    static func group(_ entries: [LogEntry]) -> [LogGroup] {
        let grouped = Dictionary(grouping: entries) { entry in
            "\(entry.subsystem)|\(entry.category)"
        }

        return grouped.map { _, entries in
            let sorted = entries.sorted { $0.timestamp > $1.timestamp }
            return LogGroup(
                id: "\(sorted[0].subsystem)|\(sorted[0].category)",
                subsystem: sorted[0].subsystem,
                category: sorted[0].category,
                entries: sorted
            )
        }
        .sorted { $0.latestTimestamp > $1.latestTimestamp }
    }

    private static func processDescription(_ name: String) -> String {
        guard name != L10n.ru("Система", en: "System"), !name.isEmpty else { return L10n.ru("система", en: "system") }
        return L10n.ru("процесс «\(name)»", en: "process “\(name)”")
    }

    private static func hasCrashSignal(in message: String) -> Bool {
        let lowercased = message.lowercased()
        let signals = [
            "crash", "sigabrt", "sigsegv", "sigbus", "sigkill",
            "abort", "exited abnormally", "fatal error", "segmentation fault"
        ]
        return signals.contains { lowercased.contains($0) }
    }

    private static func reasonSuffix(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "." }
        return L10n.ru(". Подробнее: \(trimmed)", en: ". Details: \(trimmed)")
    }

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let mediumDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension String {
    var prettyCamelCase: String {
        let withSpaces = replacingOccurrences(
            of: "([a-z0-9])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        return withSpaces
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                guard let first = word.first else { return "" }
                return first.uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
