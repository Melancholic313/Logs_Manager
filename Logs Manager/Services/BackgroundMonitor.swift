import Foundation
import Combine
import UserNotifications
import AppKit

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@MainActor
final class BackgroundMonitor: ObservableObject {
    struct BackgroundAlert: Identifiable {
        let id: String
        let date: Date
        let level: LogLevel
        let title: String
        let body: String
    }

    private struct CheckResult: Sendable {
        let entries: [LogEntry]
        let accessMessage: String?
    }

    @Published private(set) var isRunning = false
    @Published private(set) var lastCheck: Date?
    @Published private(set) var recentAlerts: [BackgroundAlert] = []
    @Published private(set) var accessMessage: String?

    private var task: Task<Void, Never>?
    private var highCPUTask: Task<Void, Never>?
    private var levels: Set<LogLevel> = [.error, .fault]
    private var notifiedIDs: Set<String>
    private var didSendAccessNotice = false
    private var lastNotificationDate: Date?
    private var highCPUPrevious: [Int32: UInt64] = [:]
    private var highCPUPreviousWall: UInt64?
    private var sustainedHighCPU: [Int32: Date] = [:]
    private var highCPULastNotification: [Int32: Date] = [:]

    private let notifiedIDsKey = "backgroundNotifiedEventIDs"
    private let maxStoredIDs = 300
    private let minNotificationInterval: TimeInterval = 30
    private let highCPUThreshold: Double = 80
    private let highCPUSustainSeconds: TimeInterval = 30
    private let highCPUNotificationCooldown: TimeInterval = 300

    init() {
        let savedIDs = UserDefaults.standard.stringArray(forKey: notifiedIDsKey) ?? []
        notifiedIDs = Set(savedIDs.suffix(maxStoredIDs))
    }

    func configure(settings: AppSettings) {
        let newLevels = settings.notificationLevels
        updateLogMonitoring(
            enabled: settings.backgroundMonitoringEnabled,
            levels: newLevels
        )
        updateHighCPUMonitoring(
            enabled: settings.backgroundMonitoringEnabled && settings.highCPUNotificationEnabled
        )
    }

    private func updateLogMonitoring(enabled: Bool, levels: Set<LogLevel>) {
        if enabled {
            if !isRunning || self.levels != levels {
                start(levels: levels)
            }
        } else {
            stopLogMonitoring()
        }
    }

    private func updateHighCPUMonitoring(enabled: Bool) {
        if enabled {
            startHighCPUMonitoring()
        } else {
            stopHighCPUMonitoring()
        }
    }

    func start(levels: Set<LogLevel>) {
        self.levels = levels

        task?.cancel()
        task = Task { [weak self] in
            await self?.runLoop(levels: levels)
        }
        isRunning = true
    }

    func stop() {
        stopLogMonitoring()
        stopHighCPUMonitoring()
    }

    private func stopLogMonitoring() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    private func startHighCPUMonitoring() {
        highCPUTask?.cancel()
        highCPUTask = Task { [weak self] in
            _ = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false

            while !Task.isCancelled {
                let previousCPU = await MainActor.run { self?.highCPUPrevious ?? [:] }
                let previousWall = await MainActor.run { self?.highCPUPreviousWall }

                let snapshot = await Task.detached(priority: .utility) {
                    ProcessMetricsReader.capture(
                        previousCPU: previousCPU,
                        previousGPU: [:],
                        previousHost: nil,
                        previousWall: previousWall
                    )
                }.value

                await MainActor.run {
                    self?.processHighCPU(snapshot)
                }

                do {
                    let sleepNanos: UInt64 = AppActivityState.shared.isLowPriority
                        ? 60_000_000_000
                        : 20_000_000_000
                    try await Task.sleep(nanoseconds: sleepNanos)
                } catch {
                    break
                }
            }
        }
    }

    private func stopHighCPUMonitoring() {
        highCPUTask?.cancel()
        highCPUTask = nil
        highCPUPrevious = [:]
        highCPUPreviousWall = nil
        sustainedHighCPU.removeAll()
    }

    private func runLoop(levels: Set<LogLevel>) async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if !granted {
            accessMessage = L10n.ru("Уведомления запрещены в системных настройках.", en: "Notifications are disabled in System Settings.")
        }

        while !Task.isCancelled {
            if !levels.isEmpty {
                let result = await Self.checkOnce(levels: levels)
                guard !Task.isCancelled else { break }
                process(result: result)
            }

            do {
                let sleepNanos: UInt64 = AppActivityState.shared.isLowPriority
                    ? 60_000_000_000
                    : 20_000_000_000
                try await Task.sleep(nanoseconds: sleepNanos)
            } catch {
                break
            }
        }
    }

    private func process(result: CheckResult) {
        lastCheck = Date()

        if let accessMessage = result.accessMessage {
            self.accessMessage = accessMessage
            if !didSendAccessNotice {
                didSendAccessNotice = true
                scheduleAccessNotice(accessMessage)
            }
        } else {
            accessMessage = nil
        }

        let newEntries = result.entries.filter { !notifiedIDs.contains($0.id) }
        guard !newEntries.isEmpty else { return }

        for entry in newEntries {
            notifiedIDs.insert(entry.id)
        }
        trimNotifiedIDsIfNeeded()
        persistNotifiedIDs()

        guard shouldSendNotificationNow else { return }

        let alert = makeCoalescedAlert(from: newEntries)
        recentAlerts.insert(alert, at: 0)
        if recentAlerts.count > 10 {
            recentAlerts = Array(recentAlerts.prefix(10))
        }
        schedule(alert)
        lastNotificationDate = Date()
    }

    private func makeCoalescedAlert(from entries: [LogEntry]) -> BackgroundAlert {
        let faults = entries.filter { $0.messageType == .fault }
        let errors = entries.filter { $0.messageType == .error }
        let defaults = entries.filter { $0.messageType == .default }

        let primary: LogLevel
        let title: String
        let count: Int

        if !faults.isEmpty {
            primary = .fault
            title = L10n.ru("Критические сбои в логах", en: "Critical Failures in Logs")
            count = faults.count
        } else if !errors.isEmpty {
            primary = .error
            title = L10n.ru("Ошибки в логах", en: "Errors in Logs")
            count = errors.count
        } else {
            primary = .default
            title = L10n.ru("События в логах", en: "Events in Logs")
            count = defaults.count
        }

        let first = entries.sorted { $0.timestamp > $1.timestamp }.first
        let detail = first.map { LogHumanizer.humanizedSentence(for: $0) } ?? ""
        let body = count == 1 ? detail : L10n.ru("Найдено \(count) событий. Первое: \(detail)", en: "Found \(count) events. First: \(detail)")

        return BackgroundAlert(
            id: UUID().uuidString,
            date: Date(),
            level: primary,
            title: title,
            body: body
        )
    }

    private var shouldSendNotificationNow: Bool {
        guard let last = lastNotificationDate else { return true }
        return Date().timeIntervalSince(last) >= minNotificationInterval
    }

    private func schedule(_ alert: BackgroundAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        attachAppIcon(to: content)

        let request = UNNotificationRequest(
            identifier: alert.id,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleAccessNotice(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = L10n.ru("Ограниченный доступ к системным логам", en: "Limited Access to System Logs")
        content.body = message
        content.sound = .default
        attachAppIcon(to: content)

        let request = UNNotificationRequest(
            identifier: "background-access-notice",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func processHighCPU(_ snapshot: ProcessMetricsSnapshot) {
        highCPUPrevious = snapshot.newCPU
        highCPUPreviousWall = snapshot.wallNanos

        let now = Date()
        var activePIDs: Set<Int32> = []

        for process in snapshot.processes where process.cpuPercent >= highCPUThreshold {
            activePIDs.insert(process.pid)

            if sustainedHighCPU[process.pid] == nil {
                sustainedHighCPU[process.pid] = now
            }

            guard let started = sustainedHighCPU[process.pid],
                  now.timeIntervalSince(started) >= highCPUSustainSeconds else {
                continue
            }

            let lastNotification = highCPULastNotification[process.pid] ?? .distantPast
            guard now.timeIntervalSince(lastNotification) >= highCPUNotificationCooldown else {
                continue
            }

            scheduleHighCPUNotification(process)
            highCPULastNotification[process.pid] = now
        }

        sustainedHighCPU = sustainedHighCPU.filter { activePIDs.contains($0.key) }
    }

    private func scheduleHighCPUNotification(_ process: ProcessMetricSample) {
        let content = UNMutableNotificationContent()
        content.title = L10n.ru("Высокая нагрузка ЦПУ", en: "High CPU Load")
        content.body = L10n.ru("Процесс «\(process.name)» использует более 80% ЦПУ дольше 30 секунд.", en: "Process “\(process.name)” has used more than 80% CPU for over 30 seconds.")
        content.sound = .default
        attachAppIcon(to: content)

        let request = UNNotificationRequest(
            identifier: "high-cpu-\(process.pid)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func attachAppIcon(to content: UNMutableNotificationContent) {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else {
            return
        }

        let roundedIcon = roundedDockIcon(from: icon)
        guard let tiff = roundedIcon.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("notification-app-icon-\(UUID().uuidString).png")
        do {
            try png.write(to: fileURL, options: .atomic)
            let attachment = try UNNotificationAttachment(
                identifier: UUID().uuidString,
                url: fileURL,
                options: nil
            )
            content.attachments = [attachment]
        } catch {
            return
        }
    }

    private func roundedDockIcon(from source: NSImage) -> NSImage {
        let size = NSSize(width: 128, height: 128)
        let rounded = NSImage(size: size)
        rounded.lockFocus()

        let margin = size.width * 0.10
        let iconRect = NSRect(
            x: margin,
            y: margin,
            width: size.width - margin * 2,
            height: size.height - margin * 2
        )
        let cornerRadius = iconRect.width * 0.225
        let path = NSBezierPath(
            roundedRect: iconRect,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )

        NSGraphicsContext.current?.saveGraphicsState()
        path.addClip()
        source.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.current?.restoreGraphicsState()

        rounded.unlockFocus()
        return rounded
    }

    private func trimNotifiedIDsIfNeeded() {
        guard notifiedIDs.count > maxStoredIDs else { return }
        notifiedIDs = Set(Array(notifiedIDs).suffix(maxStoredIDs))
    }

    private func persistNotifiedIDs() {
        UserDefaults.standard.set(Array(notifiedIDs), forKey: notifiedIDsKey)
    }

    nonisolated private static func checkOnce(levels: Set<LogLevel>) async -> CheckResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = checkOnceSynchronously(levels: levels)
                continuation.resume(returning: result)
            }
        }
    }

    nonisolated private static func checkOnceSynchronously(levels: Set<LogLevel>) -> CheckResult {
        autoreleasepool {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            process.arguments = [
                "show",
                "--last", "10s",
                "--style", "ndjson",
                "--predicate", predicate(for: levels)
            ]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                return CheckResult(
                    entries: [],
                    accessMessage: L10n.ru("Не удалось запустить log show: \(error.localizedDescription)", en: "Could not run log show: \(error.localizedDescription)")
                )
            }

            var outputData = Data()
            var errorData = Data()
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global(qos: .utility).async {
                outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            group.enter()
            DispatchQueue.global(qos: .utility).async {
                errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            process.waitUntilExit()
            group.wait()
            process.terminationHandler = nil

            if process.terminationStatus != 0 {
                let detail = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? L10n.ru("неизвестная ошибка", en: "unknown error")
                let limited = detail.localizedCaseInsensitiveContains("not permitted")
                    || detail.localizedCaseInsensitiveContains("operation not permitted")
                    || detail.localizedCaseInsensitiveContains("cannot run while sandboxed")

                let message = limited
                    ? L10n.ru("Системные логи недоступны. Работаем в режиме ограниченного доступа — только пользовательские данные.", en: "System logs are unavailable. Running in limited-access mode — user data only.")
                    : L10n.ru("Ограниченный доступ к системным логам: \(detail)", en: "Limited access to system logs: \(detail)")
                return CheckResult(entries: [], accessMessage: message)
            }

            guard let text = String(data: outputData, encoding: .utf8) else {
                return CheckResult(entries: [], accessMessage: nil)
            }

            let entries = text
                .split(separator: "\n", omittingEmptySubsequences: true)
                .prefix(2_000)
                .compactMap { line -> LogEntry? in
                    guard let data = line.data(using: .utf8),
                          let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]),
                          let dictionary = object as? [String: Any] else {
                        return nil
                    }
                    return LogEntry.parse(dictionary)
                }

            return CheckResult(entries: entries, accessMessage: nil)
        }
    }

    nonisolated private static func predicate(for levels: Set<LogLevel>) -> String {
        guard !levels.isEmpty else {
            return "messageType == \"__log_level_disabled__\""
        }
        let parts = levels
            .sorted { $0.rawValue < $1.rawValue }
            .map { "messageType == \"\($0.rawValue.lowercased())\"" }
        return parts.joined(separator: " OR ")
    }
}
