import Foundation

struct LogLoadProgress: Sendable {
    let processed: Int
    let total: Int?
}

enum LogReader {
    struct ReaderError: LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }

    static func load(
        window: String,
        onProgress: @escaping @Sendable (LogLoadProgress) -> Void
    ) async throws -> [LogEntry] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let entries = try loadSynchronously(window: window, onProgress: onProgress)
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func load(between start: Date, and end: Date) async throws -> [LogEntry] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let entries = try loadSynchronously(
                        arguments: [
                            "show",
                            "--start", Self.commandDateFormatter.string(from: start),
                            "--end", Self.commandDateFormatter.string(from: end),
                            "--style", "ndjson",
                            "--info",
                            "--debug"
                        ]
                    )
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func loadSynchronously(
        window: String,
        onProgress: @escaping @Sendable (LogLoadProgress) -> Void
    ) throws -> [LogEntry] {
        try autoreleasepool {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            process.arguments = [
                "show",
                "--style", "ndjson",
                "--last", window,
                "--info",
                "--debug"
            ]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

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

            guard process.terminationStatus == 0 else {
                let detail = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? L10n.ru("неизвестная ошибка", en: "unknown error")
                throw ReaderError(message: L10n.ru("Не удалось прочитать системный журнал: \(detail)", en: "Could not read system log: \(detail)"))
            }

            guard !outputData.isEmpty else {
                onProgress(LogLoadProgress(processed: 0, total: 0))
                return []
            }

            guard let text = String(data: outputData, encoding: .utf8) else {
                throw ReaderError(message: L10n.ru("Не удалось прочитать ответ команды log show.", en: "Could not read log show output."))
            }

            var total = 0
            text.enumerateLines { _, _ in
                total += 1
            }

            guard total > 0 else {
                onProgress(LogLoadProgress(processed: 0, total: 0))
                return []
            }

            let progressStride = max(1, total / 100)
            var parsed: [LogEntry] = []
            parsed.reserveCapacity(min(total, 5_000))
            var index = 0

            text.enumerateLines { line, _ in
                if let data = line.data(using: .utf8),
                   let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]),
                   let dictionary = object as? [String: Any],
                   let entry = LogEntry.parse(dictionary) {
                    parsed.append(entry)
                    if parsed.count > 5_000 {
                        parsed.removeFirst(parsed.count - 5_000)
                    }
                }

                if index == 0 || index == total - 1 || index % progressStride == 0 {
                    onProgress(LogLoadProgress(processed: index + 1, total: total))
                }
                index += 1
            }

            let sorted = parsed.sorted { $0.timestamp > $1.timestamp }
            onProgress(LogLoadProgress(processed: total, total: total))
            return sorted
        }
    }

    private static func loadSynchronously(arguments: [String]) throws -> [LogEntry] {
        try autoreleasepool {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

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

            guard process.terminationStatus == 0 else {
                let detail = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? L10n.ru("неизвестная ошибка", en: "unknown error")
                throw ReaderError(message: L10n.ru("Не удалось прочитать системный журнал: \(detail)", en: "Could not read system log: \(detail)"))
            }

            guard let text = String(data: outputData, encoding: .utf8) else {
                return []
            }

            var entries: [LogEntry] = []
            text.enumerateLines { line, _ in
                guard let data = line.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]),
                      let dictionary = object as? [String: Any],
                      let entry = LogEntry.parse(dictionary) else {
                    return
                }
                entries.append(entry)
                if entries.count > 5_000 {
                    entries.removeFirst(entries.count - 5_000)
                }
            }

            return entries.sorted { $0.timestamp > $1.timestamp }
        }
    }

    private static let commandDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
