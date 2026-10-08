import SwiftUI
import AppKit
import UniformTypeIdentifiers

private enum ProcessSort: String, CaseIterable, Identifiable {
    case cpu
    case gpu
    case memory
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: L10n.ru("ЦПУ", en: "CPU")
        case .gpu: L10n.ru("ГПУ", en: "GPU")
        case .memory: L10n.ru("ОЗУ", en: "RAM")
        case .name: L10n.ru("Имя", en: "Name")
        }
    }
}

private enum TaskManagerAlert: Identifiable {
    case error(String)
    case forceQuit(RunningApp)

    var id: String {
        switch self {
        case .error: "error"
        case .forceQuit(let app): "force-\(app.pid)"
        }
    }
}

private struct ProcessGroup: Identifiable {
    let id: String
    let name: String
    let icon: NSImage?
    let processCount: Int
    let totalCPU: Double
    let totalMemory: UInt64
}

struct TaskManagerView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: LogStore

    @StateObject private var session = LoadMonitoringSession()
    @State private var selectedPID: Int32?
    @State private var sort = ProcessSort.cpu
    @State private var showCharts = true
    @State private var runningPrograms: [RunningApp] = []
    @State private var sortedProcessCache: [ProcessMetricSample] = []
    @State private var activeAlert: TaskManagerAlert?
    @State private var isGrouped = false

    var body: some View {
        Group {
            if store.isLoading {
                waitingView
            } else {
                monitoringContent
            }
        }
        .navigationTitle(L10n.ru("Диспетчер задач", en: "Task Manager"))
        .onAppear {
            startSessionIfAllowed()
            loadRunningPrograms()
            refreshSortedCache()
        }
        .onDisappear {
            session.stop()
        }
        .onChange(of: store.isLoading) { _, isLoading in
            if isLoading {
                session.stop()
            } else {
                startSessionIfAllowed()
            }
        }
        .onChange(of: selectedPID) { _, newValue in
            session.setSelectedPID(newValue)
        }
        .onChange(of: session.processes) { _, _ in
            refreshSortedCache()
        }
        .onChange(of: sort) { _, _ in
            refreshSortedCache()
        }
        .onChange(of: settings.taskManagerLoadSettings) { _, newValue in
            guard !store.isLoading else { return }
            session.updateSettings(newValue)
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .error(let message):
                Alert(
                    title: Text(L10n.ru("Ошибка", en: "Error")),
                    message: Text(message),
                    dismissButton: .default(Text(L10n.ru("ОК", en: "OK")))
                )
            case .forceQuit(let app):
                Alert(
                    title: Text(L10n.ru("Завершить принудительно?", en: "Force Quit?")),
                    message: Text(L10n.ru("Приложение «\(app.name)» может потерять несохранённые данные.", en: "The app “\(app.name)” may lose unsaved data.")),
                    primaryButton: .destructive(Text(L10n.ru("Принудительно завершить", en: "Force Quit"))) {
                        forceTerminate(app)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var monitoringContent: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summary

                    systemStatusPanel

                    DisclosureGroup(L10n.ru("Графики нагрузки", en: "Load Charts"), isExpanded: $showCharts) {
                        LoadGraphsView(
                            systemHistory: session.systemHistory,
                            processHistory: session.selectedProcessHistory,
                            processName: session.selectedProcess?.name,
                            includeSystem: true,
                            graphResolution: settings.taskManagerLoadSettings.graphResolution,
                            header: nil
                        )
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 14)

                    HStack(alignment: .top, spacing: 14) {
                        processTable
                        runningProgramsPanel
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
                .padding(.top, 14)
            }
            .scrollContentBackground(settings.background.isCustom ? .hidden : .visible)
        }
    }

    private var systemStatusPanel: some View {
        let level = systemLoadLevel
        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(level.color)
                .frame(width: 10, height: 26)

            Text(level.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(level.color)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 14)
    }

    private var systemLoadLevel: (color: Color, title: String) {
        let cpu = session.system?.cpuPercent ?? 0
        let totalMemory = session.system?.memoryTotalBytes ?? 1
        let usedMemory = session.system?.memoryUsedBytes ?? 0
        let memoryPercent = Double(usedMemory) / Double(max(totalMemory, 1)) * 100
        let value = max(cpu, memoryPercent)

        if value < 50 {
            return (.green, L10n.ru("Лёгкая нагрузка", en: "Light Load"))
        } else if value < 80 {
            return (.yellow, L10n.ru("Средняя нагрузка", en: "Medium Load"))
        } else {
            return (.red, L10n.ru("Высокая нагрузка", en: "High Load"))
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Text(L10n.ru("Диспетчер задач", en: "Task Manager"))
                .font(.title2.weight(.semibold))

            Picker(L10n.ru("Сортировка", en: "Sort"), selection: $sort) {
                ForEach(ProcessSort.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .frame(width: 180)

            Picker(L10n.ru("Вид", en: "View"), selection: $isGrouped) {
                Text(L10n.ru("Список", en: "List")).tag(false)
                Text(L10n.ru("Группы", en: "Groups")).tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            Spacer()

            if let message = session.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button {
                toggleRecording()
            } label: {
                Label(
                    session.isRecording ? L10n.ru("Остановить запись", en: "Stop Recording") : L10n.ru("Запись", en: "Record"),
                    systemImage: session.isRecording ? "stop.circle" : "record.circle"
                )
            }
            .buttonStyle(.bordered)

            Button {
                export()
            } label: {
                Label(L10n.ru("Экспорт…", en: "Export…"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            metricCard(
                title: L10n.ru("ЦПУ", en: "CPU"),
                systemImage: "cpu",
                color: .blue,
                value: percentText(session.system?.cpuPercent ?? 0),
                detail: L10n.ru("все процессы", en: "all processes")
            )
            metricCard(
                title: L10n.ru("ГПУ", en: "GPU"),
                systemImage: "display",
                color: .purple,
                value: percentText(session.system?.gpuPercent ?? 0),
                detail: L10n.ru("все процессы", en: "all processes")
            )
            metricCard(
                title: L10n.ru("ОЗУ", en: "RAM"),
                systemImage: "memorychip",
                color: .green,
                value: memoryText(session.system?.memoryUsedBytes ?? 0),
                detail: L10n.ru("из \(memoryText(session.system?.memoryTotalBytes ?? 0))", en: "of \(memoryText(session.system?.memoryTotalBytes ?? 0))")
            )
        }
        .padding(.horizontal, 14)
    }

    private func metricCard(
        title: String,
        systemImage: String,
        color: Color,
        value: String,
        detail: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var processTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.ru("Приложения и процессы", en: "Apps and Processes"))
                .font(.headline)
                .padding(.bottom, 8)

            LazyVStack(spacing: 3) {
                if isGrouped {
                    groupedHeaderRow
                    ForEach(groupedProcesses.prefix(120)) { group in
                        groupRow(group)
                    }
                } else {
                    processHeaderRow
                    ForEach(sortedProcessCache.prefix(200)) { process in
                        processRow(process)
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var groupedHeaderRow: some View {
        HStack(spacing: 12) {
            Text(L10n.ru("Программа", en: "Program"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.ru("Процессы", en: "Processes"))
                .frame(width: 70, alignment: .trailing)
            Text(L10n.ru("ЦПУ", en: "CPU"))
                .frame(width: 72, alignment: .trailing)
            Text(L10n.ru("ОЗУ", en: "RAM"))
                .frame(width: 92, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
    }

    private func groupRow(_ group: ProcessGroup) -> some View {
        HStack(spacing: 12) {
            if let icon = group.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
            }
            Text(group.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(group.processCount)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
            Text(percentText(group.totalCPU))
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
            Text(memoryText(group.totalMemory))
                .monospacedDigit()
                .frame(width: 92, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(.regularMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var processHeaderRow: some View {
        HStack(spacing: 12) {
            Text(L10n.ru("Процесс", en: "Process"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("PID")
                .frame(width: 52, alignment: .trailing)
            Text(L10n.ru("ЦПУ", en: "CPU"))
                .frame(width: 72, alignment: .trailing)
            Text(L10n.ru("ГПУ", en: "GPU"))
                .frame(width: 72, alignment: .trailing)
            Text(L10n.ru("ОЗУ", en: "RAM"))
                .frame(width: 92, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
    }

    private func processRow(_ process: ProcessMetricSample) -> some View {
        HStack(spacing: 12) {
            Text(process.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(process.pid)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
            Text(percentText(process.cpuPercent))
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
            Text(process.gpuPercent.map { percentText($0) } ?? "—")
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
            Text(memoryText(process.memoryBytes))
                .monospacedDigit()
                .frame(width: 92, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            selectedPID == process.pid ? Color.accentColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedPID = selectedPID == process.pid ? nil : process.pid
        }
    }

    private var runningProgramsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.ru("Запущенные программы", en: "Running Programs"))
                .font(.headline)

            ForEach(runningPrograms) { app in
                HStack(spacing: 8) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "app")
                            .frame(width: 20, height: 20)
                    }

                    Text(app.name)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 4)

                    Button {
                        softTerminate(app)
                    } label: {
                        Text(L10n.ru("Завершить", en: "Quit"))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(L10n.ru("Завершить программу", en: "Quit app"))

                    Button {
                        requestForceQuit(app)
                    } label: {
                        Text(L10n.ru("Завершить принудительно", en: "Force Quit"))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                    .help(L10n.ru("Завершить принудительно", en: "Force quit"))
                }
                .padding(.vertical, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var groupedProcesses: [ProcessGroup] {
        let appsByPID = Dictionary(
            uniqueKeysWithValues: runningPrograms.map { ($0.pid, $0) }
        )

        var buckets: [String: (name: String, icon: NSImage?, cpu: Double, memory: UInt64, count: Int)] = [:]

        for process in sortedProcessCache {
            let key: String
            let name: String
            let icon: NSImage?

            if let app = appsByPID[process.pid] {
                key = app.bundleID.isEmpty ? "app-\(app.pid)" : app.bundleID
                name = app.name
                icon = app.icon
            } else {
                key = "process-\(process.name)"
                name = process.name
                icon = nil
            }

            var bucket = buckets[key] ?? (name, icon, 0, 0, 0)
            bucket.cpu += process.cpuPercent
            bucket.memory += process.memoryBytes
            bucket.count += 1
            buckets[key] = bucket
        }

        return buckets.map { key, value in
            ProcessGroup(
                id: key,
                name: value.name,
                icon: value.icon,
                processCount: value.count,
                totalCPU: value.cpu,
                totalMemory: value.memory
            )
        }
        .sorted { $0.totalCPU > $1.totalCPU }
    }

    private func refreshSortedCache() {
        sortedProcessCache = session.processes.sorted { lhs, rhs in
            switch sort {
            case .cpu:
                return lhs.cpuPercent > rhs.cpuPercent
            case .gpu:
                return (lhs.gpuPercent ?? -1) > (rhs.gpuPercent ?? -1)
            case .memory:
                return lhs.memoryBytes > rhs.memoryBytes
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private var waitingView: some View {
        ContentUnavailableView {
            Label(L10n.ru("Завершаем индексацию логов", en: "Finishing Log Indexing"), systemImage: "hourglass")
        } description: {
            Text(L10n.ru("Мониторинг нагрузки начнётся сразу после загрузки журнала, чтобы не замедлять запуск программы.", en: "Load monitoring starts after log loading to avoid slowing down startup."))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startSessionIfAllowed() {
        guard !store.isLoading else {
            session.stop()
            return
        }
        startSession()
    }

    private func startSession() {
        session.start(
            settings: settings.taskManagerLoadSettings,
            selectedPID: selectedPID,
            recordAllProcesses: true,
            processListRefreshInterval: 3.0
        )
    }

    private func loadRunningPrograms() {
        runningPrograms = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier > 0 }
            .map { app in
                RunningApp(
                    pid: app.processIdentifier,
                    name: app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? L10n.ru("Приложение", en: "App"),
                    bundleID: app.bundleIdentifier ?? "",
                    version: nil,
                    icon: app.icon
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func runningApplication(for app: RunningApp) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.processIdentifier == app.pid
        }
    }

    private func softTerminate(_ app: RunningApp) {
        _ = runningApplication(for: app)?.terminate()
        refreshRunningProgramsSoon()
    }

    private func requestForceQuit(_ app: RunningApp) {
        activeAlert = .forceQuit(app)
    }

    private func forceTerminate(_ app: RunningApp) {
        _ = runningApplication(for: app)?.forceTerminate()
        refreshRunningProgramsSoon()
    }

    private func refreshRunningProgramsSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
            loadRunningPrograms()
        }
    }

    private func toggleRecording() {
        if session.isRecording {
            session.setRecording(false)
            return
        }

        if settings.taskManagerLoadSettings.saveDirectoryPath == nil {
            guard chooseDirectory() != nil else { return }
            session.updateSettings(settings.taskManagerLoadSettings)
        }
        session.setRecording(true)
    }

    private func export() {
        guard !session.processes.isEmpty else {
            activeAlert = .error(L10n.ru("Пока нет данных для экспорта.", en: "No data to export yet."))
            return
        }

        switch settings.taskManagerLoadSettings.contentMode {
        case .text:
            guard let url = savePanel(fileExtension: "csv", type: .commaSeparatedText) else { return }
            do {
                try session.exportText(to: url)
            } catch {
                activeAlert = .error(error.localizedDescription)
            }
        case .graph:
            guard let url = savePanel(fileExtension: "png", type: .png) else { return }
            do {
                try session.exportGraph(to: url)
            } catch {
                activeAlert = .error(error.localizedDescription)
            }
        case .both:
            guard let url = chooseDirectory() else { return }
            do {
                try session.exportBoth(to: url)
            } catch {
                activeAlert = .error(error.localizedDescription)
            }
        }
    }

    @discardableResult
    private func chooseDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.title = L10n.ru("Выберите папку для записей нагрузки", en: "Choose a folder for load recordings")
        panel.prompt = L10n.ru("Выбрать", en: "Choose")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        settings.taskManagerLoadSettings.saveDirectoryPath = url.path
        return url
    }

    private func savePanel(fileExtension: String, type: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.title = L10n.ru("Экспорт нагрузки", en: "Export Load")
        panel.prompt = L10n.ru("Экспортировать", en: "Export")
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = L10n.ru("Нагрузка.\(fileExtension)", en: "Load.\(fileExtension)")
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func percentText(_ value: Double) -> String {
        String(format: "%.1f %%", value)
    }

    private func memoryText(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}
