import Foundation

enum AppLogReader {
    struct ReaderError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func fetch(
        processID: Int32,
        windowSeconds: Int,
        levels: Set<LogLevel>
    ) async throws -> [LogEntry] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let entries = try fetchSynchronously(
                        processID: processID,
                        windowSeconds: windowSeconds,
                        levels: levels
                    )
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func fetchSynchronously(
        processID: Int32,
        windowSeconds: Int,
        levels: Set<LogLevel>
    ) throws -> [LogEntry] {
        try autoreleasepool {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            process.arguments = [
                "show",
                "--last", "\(max(windowSeconds, 1))s",
                "--style", "ndjson",
                "--predicate", "processIdentifier == \(processID)",
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
                throw ReaderError(message: detail)
            }

            guard let text = String(data: outputData, encoding: .utf8) else {
                return []
            }

            var entries: [LogEntry] = []
            text.enumerateLines { line, _ in
                guard let data = line.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]),
                      let dictionary = object as? [String: Any],
                      let entry = LogEntry.parse(dictionary),
                      levels.contains(entry.messageType) else {
                    return
                }
                entries.append(entry)
                if entries.count > 1_000 {
                    entries.removeFirst(entries.count - 1_000)
                }
            }

            return entries.sorted { $0.timestamp > $1.timestamp }
        }
    }
}
