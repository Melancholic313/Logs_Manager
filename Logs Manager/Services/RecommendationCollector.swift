import Foundation

enum RecommendationCollector {
    nonisolated static func buildSnapshot(
        logEntries: [LogEntry],
        historySamples: [SystemLoadSample]
    ) async -> RecommendationSnapshot {
        let history = historySamples
            .filter { Date().timeIntervalSince($0.timestamp) <= 15 * 60 }

        let first = ProcessMetricsReader.capture(
            previousCPU: [:],
            previousGPU: [:],
            previousHost: nil,
            previousWall: nil
        )

        let second: ProcessMetricsSnapshot
        if history.isEmpty {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            second = ProcessMetricsReader.capture(
                previousCPU: first.newCPU,
                previousGPU: [:],
                previousHost: first.host,
                previousWall: first.wallNanos
            )
        } else {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            second = ProcessMetricsReader.capture(
                previousCPU: first.newCPU,
                previousGPU: [:],
                previousHost: first.host,
                previousWall: first.wallNanos
            )
        }

        let systemSamples: [SystemLoadSamplePayload]
        if history.isEmpty {
            systemSamples = [payload(from: second.system)]
        } else {
            systemSamples = history.map(payload(from:))
        }

        let processes = second.processes
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(10)
            .map {
                ProcessPayload(
                    name: sanitize($0.name),
                    pid: $0.pid,
                    cpu: $0.cpuPercent,
                    memory: $0.memoryBytes
                )
            }

        let logs = uniqueLogs(logEntries)

        return RecommendationSnapshot(
            systemLoad: systemSamples,
            topProcesses: Array(processes),
            logs: logs
        )
    }

    nonisolated private static func payload(from sample: SystemLoadSample) -> SystemLoadSamplePayload {
        SystemLoadSamplePayload(
            timestamp: sample.timestamp,
            cpu: sample.cpuPercent,
            gpu: sample.gpuPercent,
            memoryUsed: sample.memoryUsedBytes,
            memoryTotal: sample.memoryTotalBytes
        )
    }

    nonisolated private static func uniqueLogs(_ entries: [LogEntry]) -> [LogPayload] {
        var seen = Set<String>()
        var result: [LogPayload] = []

        for entry in entries
            .filter({ $0.messageType == .error || $0.messageType == .fault })
            .sorted(by: { $0.timestamp > $1.timestamp }) {
            let key = entry.eventMessage.isEmpty ? entry.formatString : entry.eventMessage
            guard !seen.contains(key), result.count < 20 else { continue }
            seen.insert(key)
            result.append(
                LogPayload(
                    timestamp: entry.timestamp,
                    level: entry.messageType.rawValue,
                    process: sanitize(entry.processName),
                    message: sanitize(
                        entry.eventMessage.isEmpty
                            ? (entry.formatString.isEmpty ? "—" : entry.formatString)
                            : entry.eventMessage
                    )
                )
            )
        }

        return result
    }

    nonisolated private static func sanitize(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "/Users/[^/]+/") else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: "/Users/[user]/"
        )
    }
}
