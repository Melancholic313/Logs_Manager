import Foundation
import Combine

struct DailyCPULoad: Codable {
    var cpuSum: Double = 0
    var sampleCount: Int = 0

    var average: Double {
        sampleCount > 0 ? cpuSum / Double(sampleCount) : 0
    }
}

@MainActor
final class AppLoadHistoryStore: ObservableObject {
    private var data: [String: [String: DailyCPULoad]] = [:]
    private var lastSave = Date.distantPast
    private let saveInterval: TimeInterval = 60

    init() {
        load()
    }

    func record(bundleID: String, cpuPercent: Double) {
        guard !bundleID.isEmpty else { return }
        let key = Self.dayKey(for: Date())
        var appData = data[bundleID, default: [:]]
        var day = appData[key, default: DailyCPULoad()]
        day.cpuSum += cpuPercent
        day.sampleCount += 1
        appData[key] = day
        data[bundleID] = appData
        saveIfNeeded()
    }

    func comparisonPercent(
        bundleID: String,
        retentionDays: Int,
        currentCPU: Double
    ) -> Int? {
        let days = data[bundleID] ?? [:]
        let today = Self.dayKey(for: Date())
        let past = days
            .filter { $0.key != today }
            .compactMap { entry -> (date: Date, load: DailyCPULoad)? in
                guard let date = Self.date(from: entry.key) else { return nil }
                return (date, entry.value)
            }
            .sorted { $0.date > $1.date }
            .prefix(max(retentionDays, 1))

        let totalSum = past.reduce(0.0) { $0 + $1.load.cpuSum }
        let totalCount = past.reduce(0) { $0 + $1.load.sampleCount }
        guard totalCount > 0 else { return nil }

        let baseline = totalSum / Double(totalCount)
        guard baseline > 0 else { return nil }
        return Int(((currentCPU - baseline) / baseline) * 100)
    }

    func flush() {
        save()
    }

    private func saveIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastSave) >= saveInterval else { return }
        save()
    }

    private func load() {
        let url = Self.storageURL
        guard let fileData = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String: DailyCPULoad]].self, from: fileData) else {
            return
        }
        data = decoded
        prune(maxDays: 30)
    }

    private func save() {
        prune(maxDays: 30)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let fileData = try? encoder.encode(data) else { return }
        try? FileManager.default.createDirectory(
            at: Self.storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? fileData.write(to: Self.storageURL, options: .atomic)
        lastSave = Date()
    }

    private func prune(maxDays: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxDays, to: Date()) ?? Date()
        let cutoffKey = Self.dayKey(for: cutoff)
        for bundleID in data.keys {
            let kept = data[bundleID]?.filter { $0.key >= cutoffKey }
            data[bundleID] = kept
        }
    }

    private static var storageURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Logs Manager", isDirectory: true)
            .appendingPathComponent("load_history.json")
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static func date(from key: String) -> Date? {
        dayFormatter.date(from: key)
    }
}
