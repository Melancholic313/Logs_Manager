import Foundation
import Combine

struct TimeTravelBucket: Identifiable, Sendable {
    let timestamp: Date
    let entries: [LogEntry]

    var id: Date { timestamp }
}

private final class TimeTravelParser: @unchecked Sendable {
    private let lock = NSLock()
    private let bucketInterval: TimeInterval
    private let maxEntriesPerBucket: Int
    nonisolated(unsafe) private var buffer = Data()
    nonisolated(unsafe) private var buckets: [Date: [LogEntry]] = [:]

    nonisolated init(bucketInterval: TimeInterval, maxEntriesPerBucket: Int) {
        self.bucketInterval = bucketInterval
        self.maxEntriesPerBucket = maxEntriesPerBucket
    }

    nonisolated func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }

        buffer.append(data)
        while let newlineRange = buffer.range(of: Data([0x0A])) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<newlineRange.upperBound)

            guard let object = try? JSONSerialization.jsonObject(with: lineData, options: [.allowFragments]),
                  let dictionary = object as? [String: Any],
                  let entry = LogEntry.parse(dictionary) else {
                continue
            }

            let bucketTime = floor(entry.timestamp.timeIntervalSince1970 / bucketInterval) * bucketInterval
            let bucketDate = Date(timeIntervalSince1970: bucketTime)
            var bucketEntries = buckets[bucketDate, default: []]
            if bucketEntries.count < maxEntriesPerBucket {
                bucketEntries.append(entry)
                buckets[bucketDate] = bucketEntries
            }
        }
    }

    nonisolated func result() -> [TimeTravelBucket] {
        lock.lock()
        defer { lock.unlock() }
        return buckets.keys
            .sorted()
            .map { TimeTravelBucket(timestamp: $0, entries: buckets[$0] ?? []) }
    }
}

@MainActor
final class TimeTravelStore: ObservableObject {
    @Published var startDate = Date().addingTimeInterval(-3600)
    @Published var endDate = Date()
    @Published var buckets: [TimeTravelBucket] = []
    @Published var loadSamples: [SystemLoadSample] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var loadTask: Task<Void, Never>?

    func startAnalysis() {
        stopAnalysis()

        isLoading = true
        errorMessage = nil
        buckets = []

        let start = startDate
        let end = endDate

        loadTask = Task { [weak self] in
            do {
                let result = try await Self.loadBuckets(start: start, end: end)
                guard !Task.isCancelled else { return }
                self?.buckets = result
                self?.isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        }
    }

    func stopAnalysis() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
        buckets = []
        loadSamples.removeAll()
    }

    func recordLoadSample(_ sample: SystemLoadSample) {
        loadSamples.append(sample)
        if loadSamples.count > 180 {
            loadSamples.removeFirst(loadSamples.count - 180)
        }
    }

    func loadSample(near date: Date) -> SystemLoadSample? {
        guard !loadSamples.isEmpty else { return nil }
        return loadSamples.min {
            abs($0.timestamp.timeIntervalSince(date))
                < abs($1.timestamp.timeIntervalSince(date))
        }
    }

    private nonisolated static func loadBuckets(
        start: Date,
        end: Date
    ) async throws -> [TimeTravelBucket] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let buckets = try loadBucketsSynchronously(start: start, end: end)
                    continuation.resume(returning: buckets)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private nonisolated static func loadBucketsSynchronously(
        start: Date,
        end: Date
    ) throws -> [TimeTravelBucket] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "show",
            "--start", Self.commandDateFormatter.string(from: start),
            "--end", Self.commandDateFormatter.string(from: end),
            "--style", "ndjson",
            "--info",
            "--debug"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        let group = DispatchGroup()
        let parser = TimeTravelParser(bucketInterval: 5, maxEntriesPerBucket: 12)

        group.enter()
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                group.leave()
                return
            }

            parser.append(data)
        }

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            _ = errorHandle.readDataToEndOfFile()
            group.leave()
        }

        process.waitUntilExit()
        group.wait()
        outputHandle.readabilityHandler = nil

        return parser.result()
    }

    private nonisolated static let commandDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
