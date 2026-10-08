import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
final class LoadMonitoringSession: ObservableObject {
    @Published private(set) var processes: [ProcessMetricSample] = []
    @Published private(set) var system: SystemLoadSample?
    @Published private(set) var systemHistory: [LoadHistoryPoint] = []
    @Published private(set) var selectedProcessHistory: [LoadHistoryPoint] = []
    @Published private(set) var isSampling = false
    @Published private(set) var isRecording = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var lastExportURL: URL?

    private var timer: Timer?
    private var settings = LoadRecordingSettings()
    private var selectedPID: Int32?
    private var recordAllProcesses = false
    private var previousCPU: [Int32: UInt64] = [:]
    private var previousGPU: [Int32: UInt64] = [:]
    private var previousHost: HostCPUSample?
    private var previousWall: UInt64?
    private var recorder: LoadRecorder?
    private var isSamplingInFlight = false
    private var graphHeader: LoadGraphHeader?
    private var processListRefreshInterval: TimeInterval = 1.0
    private var lastProcessListUpdate = Date.distantPast

    func start(
        settings: LoadRecordingSettings,
        selectedPID: Int32?,
        recordAllProcesses: Bool,
        graphHeader: LoadGraphHeader? = nil,
        processListRefreshInterval: TimeInterval = 1.0
    ) {
        stop()

        self.settings = settings
        self.selectedPID = selectedPID
        self.recordAllProcesses = recordAllProcesses
        self.graphHeader = graphHeader
        self.processListRefreshInterval = processListRefreshInterval
        self.lastProcessListUpdate = .distantPast
        self.previousCPU = [:]
        self.previousGPU = [:]
        self.previousHost = nil
        self.previousWall = nil
        self.systemHistory = []
        self.selectedProcessHistory = []
        self.system = nil
        self.processes = []

        isSampling = true
        sampleNow()

        let sampleInterval = max(0.5, min(settings.textIntervalSeconds, settings.graphIntervalSeconds, 1.0))
        let timer = Timer(timeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sampleNow()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func setSelectedPID(_ pid: Int32?) {
        guard selectedPID != pid else { return }
        selectedPID = pid
        selectedProcessHistory.removeAll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        recorder?.finish()
        recorder = nil
        isSampling = false
        isRecording = false
        isSamplingInFlight = false
        statusMessage = nil
    }

    func setRecording(_ enabled: Bool) {
        guard enabled != isRecording else { return }

        if enabled {
            guard let path = settings.saveDirectoryPath, !path.isEmpty else {
                statusMessage = L10n.ru("Сначала выберите папку для записей нагрузки.", en: "Choose a folder for load recordings first.")
                return
            }

            do {
                recorder = try LoadRecorder(
                    settings: settings,
                    baseDirectory: URL(fileURLWithPath: path),
                    graphHeader: graphHeader
                )
                isRecording = true
                statusMessage = L10n.ru("Идёт запись нагрузки…", en: "Recording load…")
            } catch {
                statusMessage = error.localizedDescription
            }
        } else {
            recorder?.finish()
            recorder = nil
            isRecording = false
            statusMessage = L10n.ru("Запись остановлена.", en: "Recording stopped.")
        }
    }

    func updateSettings(_ newSettings: LoadRecordingSettings) {
        guard newSettings != settings else { return }
        let wasRecording = isRecording
        let selectedPID = selectedPID
        settings = newSettings
        stop()
        start(
            settings: newSettings,
            selectedPID: selectedPID,
            recordAllProcesses: recordAllProcesses,
            graphHeader: graphHeader,
            processListRefreshInterval: processListRefreshInterval
        )
        if wasRecording {
            setRecording(true)
        }
    }

    func exportText(to url: URL) throws {
        let rows = recordAllProcesses
            ? processes
            : [selectedProcess].compactMap { $0 }
        try LoadExporter.writeText(
            processes: rows,
            system: system,
            to: url
        )
        lastExportURL = url
    }

    func exportGraph(to url: URL) throws {
        guard let system else {
            throw LoadRecorder.RecorderError(message: L10n.ru("Нет данных для построения графика.", en: "No data to build a chart."))
        }
        let processPoints = selectedProcessHistory.isEmpty
            ? [selectedProcess?.historyPoint].compactMap { $0 }
            : selectedProcessHistory
        let image = LoadGraphRenderer.renderImage(
            systemHistory: systemHistory.isEmpty ? [system.historyPoint] : systemHistory,
            processHistory: processPoints,
            processName: selectedProcess?.name,
            includeSystem: recordAllProcesses,
            graphResolution: settings.graphResolution,
            header: graphHeader(for: Date())
        )
        guard let image,
              let data = image.pngData() else {
            throw LoadRecorder.RecorderError(message: L10n.ru("Не удалось подготовить PNG-изображение графика.", en: "Could not prepare the chart PNG image."))
        }
        try data.write(to: url, options: .atomic)
        lastExportURL = url
    }

    func exportBoth(to directory: URL) throws {
        let stamp = LoadRecorder.fileStamp(from: Date())
        let textURL = directory.appendingPathComponent(L10n.ru("Нагрузка_\(stamp).csv", en: "Load_\(stamp).csv"))
        let graphURL = directory.appendingPathComponent(L10n.ru("График_\(stamp).png", en: "Chart_\(stamp).png"))
        try exportText(to: textURL)
        try exportGraph(to: graphURL)
        lastExportURL = directory
    }

    var selectedProcess: ProcessMetricSample? {
        guard let selectedPID else { return nil }
        return processes.first { $0.pid == selectedPID }
    }

    private func graphHeader(for date: Date) -> LoadGraphHeader? {
        guard let graphHeader else { return nil }
        return LoadGraphHeader(
            title: graphHeader.title,
            subtitle: graphHeader.subtitle,
            timestamp: date
        )
    }

    private func sampleNow() {
        guard isSampling, !isSamplingInFlight else { return }
        isSamplingInFlight = true

        let previousCPU = self.previousCPU
        let previousGPU = self.previousGPU
        let previousHost = self.previousHost
        let previousWall = self.previousWall

        Task { [weak self] in
            guard let self else { return }

            let snapshot = await Task.detached(priority: .utility) {
                ProcessMetricsReader.capture(
                    previousCPU: previousCPU,
                    previousGPU: previousGPU,
                    previousHost: previousHost,
                    previousWall: previousWall
                )
            }.value

            self.apply(snapshot)
        }
    }

    private func apply(_ snapshot: ProcessMetricsSnapshot) {
        guard isSampling else {
            isSamplingInFlight = false
            return
        }
        defer { isSamplingInFlight = false }

        previousCPU = snapshot.newCPU
        previousGPU = snapshot.newGPU
        previousHost = snapshot.host
        previousWall = snapshot.wallNanos

        system = snapshot.system
        if Date().timeIntervalSince(lastProcessListUpdate) >= processListRefreshInterval {
            processes = snapshot.processes
            lastProcessListUpdate = Date()
        }
        systemHistory = Self.trimmed(
            systemHistory + [snapshot.system.historyPoint],
            count: settings.graphResolution.pointCount
        )

        if let selectedPID,
           let process = snapshot.processes.first(where: { $0.pid == selectedPID }) {
            selectedProcessHistory = Self.trimmed(
                selectedProcessHistory + [process.historyPoint],
                count: settings.graphResolution.pointCount
            )
        }

        if isRecording {
            let selectedProcess = snapshot.processes.first { $0.pid == selectedPID }
            recorder?.record(
                snapshot: snapshot,
                systemHistory: systemHistory,
                processHistory: selectedProcessHistory,
                selectedProcess: selectedProcess,
                recordAllProcesses: recordAllProcesses
            )
        }
    }

    private static func trimmed(_ points: [LoadHistoryPoint], count: Int) -> [LoadHistoryPoint] {
        guard points.count > count else { return points }
        return Array(points.suffix(count))
    }
}

@MainActor
private final class LoadRecorder {
    struct RecorderError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let settings: LoadRecordingSettings
    private let sessionDirectory: URL
    private let textFileURL: URL
    private let graphsDirectory: URL
    private let graphHeader: LoadGraphHeader?
    private var lastTextWrite = Date.distantPast
    private var lastGraphWrite = Date.distantPast
    private var textHeaderWritten = false

    init(
        settings: LoadRecordingSettings,
        baseDirectory: URL,
        graphHeader: LoadGraphHeader?
    ) throws {
        self.settings = settings
        self.graphHeader = graphHeader

        let stamp = Self.fileStamp(from: Date())
        let folderName = L10n.ru("Нагрузка_\(stamp)", en: "Load_\(stamp)")
        let sessionDirectory = baseDirectory.appendingPathComponent(folderName, isDirectory: true)
        let graphsDirectory = sessionDirectory.appendingPathComponent(L10n.ru("Графики", en: "Charts"), isDirectory: true)

        try FileManager.default.createDirectory(
            at: graphsDirectory,
            withIntermediateDirectories: true
        )

        self.sessionDirectory = sessionDirectory
        self.textFileURL = sessionDirectory.appendingPathComponent(L10n.ru("Нагрузка.csv", en: "Load.csv"))
        self.graphsDirectory = graphsDirectory
    }

    func record(
        snapshot: ProcessMetricsSnapshot,
        systemHistory: [LoadHistoryPoint],
        processHistory: [LoadHistoryPoint],
        selectedProcess: ProcessMetricSample?,
        recordAllProcesses: Bool
    ) {
        let now = Date()

        if settings.contentMode.includesText,
           now.timeIntervalSince(lastTextWrite) >= settings.textIntervalSeconds {
            writeText(
                snapshot: snapshot,
                selectedProcess: selectedProcess,
                recordAllProcesses: recordAllProcesses
            )
            lastTextWrite = now
        }

        if settings.contentMode.includesGraph,
           now.timeIntervalSince(lastGraphWrite) >= settings.graphIntervalSeconds {
            if lastGraphWrite == .distantPast {
                lastGraphWrite = now
            } else {
                writeGraph(
                    systemHistory: systemHistory,
                    processHistory: processHistory,
                    processName: selectedProcess?.name,
                    includeSystem: recordAllProcesses
                )
                lastGraphWrite = now
            }
        }
    }

    func finish() {}

    private func writeText(
        snapshot: ProcessMetricsSnapshot,
        selectedProcess: ProcessMetricSample?,
        recordAllProcesses: Bool
    ) {
        let rows = recordAllProcesses
            ? snapshot.processes.sorted { $0.cpuPercent > $1.cpuPercent }
            : [selectedProcess].compactMap { $0 }
        guard !rows.isEmpty else { return }

        var lines: [String] = []
        if !textHeaderWritten {
            lines.append("timestamp,pid,process,cpu_percent,gpu_percent,memory_bytes")
            textHeaderWritten = true
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: snapshot.system.timestamp)

        for process in rows {
            let gpu = process.gpuPercent.map { String(format: "%.2f", $0) } ?? ""
            lines.append(
                "\(timestamp),\(process.pid),\"\(Self.escapeCSV(process.name))\",\(String(format: "%.2f", process.cpuPercent)),\(gpu),\(process.memoryBytes)"
            )
        }

        append(lines.joined(separator: "\n") + "\n", to: textFileURL)
    }

    private func writeGraph(
        systemHistory: [LoadHistoryPoint],
        processHistory: [LoadHistoryPoint],
        processName: String?,
        includeSystem: Bool
    ) {
        guard let image = LoadGraphRenderer.renderImage(
            systemHistory: systemHistory,
            processHistory: processHistory,
            processName: processName,
            includeSystem: includeSystem,
            graphResolution: settings.graphResolution,
            header: graphHeader.map {
                LoadGraphHeader(
                    title: $0.title,
                    subtitle: $0.subtitle,
                    timestamp: Date()
                )
            }
        ), let data = image.pngData() else {
            return
        }

        let stamp = Self.fileStamp(from: Date())
        let url = graphsDirectory.appendingPathComponent(L10n.ru("График_\(stamp).png", en: "Chart_\(stamp).png"))
        try? data.write(to: url, options: .atomic)
    }

    private func append(_ text: String, to url: URL) {
        guard let data = text.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    nonisolated static func fileStamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }

    nonisolated static func escapeCSV(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\"\"")
    }
}

private enum LoadExporter {
    static func writeText(
        processes: [ProcessMetricSample],
        system: SystemLoadSample?,
        to url: URL
    ) throws {
        var lines = ["timestamp,pid,process,cpu_percent,gpu_percent,memory_bytes"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = system.map { formatter.string(from: $0.timestamp) } ?? formatter.string(from: Date())

        for process in processes.sorted(by: { $0.cpuPercent > $1.cpuPercent }) {
            let gpu = process.gpuPercent.map { String(format: "%.2f", $0) } ?? ""
            lines.append(
                "\(timestamp),\(process.pid),\"\(LoadRecorder.escapeCSV(process.name))\",\(String(format: "%.2f", process.cpuPercent)),\(gpu),\(process.memoryBytes)"
            )
        }

        guard let data = (lines.joined(separator: "\n") + "\n").data(using: .utf8) else {
            throw LoadRecorder.RecorderError(message: L10n.ru("Не удалось подготовить текстовые данные.", en: "Could not prepare text data."))
        }
        try data.write(to: url, options: .atomic)
    }
}
