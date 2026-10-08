import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct RunningApp: Identifiable {
    let pid: Int32
    let name: String
    let bundleID: String
    let version: String?
    let icon: NSImage?

    var id: Int32 { pid }
}

private enum AppLogsSection: String, CaseIterable, Identifiable {
    case logs
    case load

    var id: String { rawValue }

    var title: String {
        switch self {
        case .logs: L10n.ru("Логи", en: "Logs")
        case .load: L10n.ru("Нагрузка", en: "Load")
        }
    }
}

struct AppLogsView: View {
    @EnvironmentObject private var settings: AppSettings

    @StateObject private var loadSession = LoadMonitoringSession()
    @StateObject private var loadHistory = AppLoadHistoryStore()
    @Binding var selectedAppPID: Int32?
    @State private var apps: [RunningApp] = []
    @State private var entries: [LogEntry] = []
    @State private var selectedLevels: Set<LogLevel> = [.default, .error, .fault]
    @State private var refreshSeconds = 2
    @State private var isFetching = false
    @State private var lastError: String?
    @State private var refreshTimer: Timer?
    @State private var showAppPicker = false
    @State private var selectedSection: AppLogsSection = .logs
    @State private var showLoadSettings = false
    @State private var loadError: String?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                settingsPanel
                Divider()
                content
            }

            if showAppPicker {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showAppPicker = false
                    }

                processPickerPanel
            }
        }
        .onAppear {
            loadRunningApps()
            reconcileSelectedPID()
            restartFetchLoop()
            startLoadSessionIfNeeded()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            loadSession.stop()
            loadHistory.flush()
        }
        .onChange(of: selectedAppPID) { _, _ in
            restartFetchLoop()
            startLoadSessionIfNeeded()
        }
        .onChange(of: refreshSeconds) { _, _ in
            restartFetchLoop()
        }
        .onChange(of: selectedLevels) { _, _ in
            restartFetchLoop()
        }
        .onChange(of: settings.appLogsLoadSettings) { _, newValue in
            loadSession.updateSettings(newValue)
        }
        .onChange(of: loadSession.selectedProcess) { _, process in
            guard let process, let app = selectedApp else { return }
            loadHistory.record(bundleID: app.bundleID, cpuPercent: process.cpuPercent)
        }
        .alert(
            L10n.ru("Ошибка", en: "Error"),
            isPresented: Binding(
                get: { loadError != nil },
                set: { if !$0 { loadError = nil } }
            )
        ) {
            Button(L10n.ru("ОК", en: "OK"), role: .cancel) {}
        } message: {
            Text(loadError ?? "")
        }
    }

    private var settingsPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    showAppPicker = true
                } label: {
                    HStack(spacing: 8) {
                        if let app = selectedApp {
                            appIconView(app.icon, size: 22)
                            Text(app.name)
                        } else {
                            Image(systemName: "app.dashed")
                            Text(L10n.ru("Выберите приложение", en: "Choose App"))
                        }
                    }
                    .frame(maxWidth: 230, alignment: .leading)
                }
                .buttonStyle(.bordered)

                HStack(spacing: 6) {
                    Text(L10n.ru("Раздел", en: "Section"))
                        .fixedSize()
                    Picker("", selection: $selectedSection) {
                        ForEach(AppLogsSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                Spacer()

                Button {
                    showLoadSettings = true
                } label: {
                    Label(L10n.ru("Настройки мониторинга нагрузки", en: "Load Monitoring Settings"), systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .popover(isPresented: $showLoadSettings, arrowEdge: .bottom) {
                    Form {
                        LoadSettingsEditor(
                            settings: $settings.appLogsLoadSettings,
                            contentLabel: L10n.ru("Содержимое отображения и записи", en: "Display and Recording Content")
                        )
                    }
                    .formStyle(.grouped)
                    .id(settings.language)
                    .padding(8)
                    .frame(width: 540)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.ru("Уровни", en: "Levels"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LogLevel.allCases) { level in
                                Toggle(level.displayName, isOn: levelBinding(level))
                                    .toggleStyle(.checkbox)
                                    .fixedSize()
                            }
                        }
                    }
                }

                Spacer()

                Picker(L10n.ru("Обновление", en: "Refresh"), selection: $refreshSeconds) {
                    Text(L10n.ru("1 с", en: "1 sec")).tag(1)
                    Text(L10n.ru("2 с", en: "2 sec")).tag(2)
                    Text(L10n.ru("5 с", en: "5 sec")).tag(5)
                    Text(L10n.ru("10 с", en: "10 sec")).tag(10)
                    Text(L10n.ru("30 с", en: "30 sec")).tag(30)
                }
                .frame(width: 130)
            }
        }
        .padding(12)
    }

    private var processPickerPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.ru("Выберите приложение", en: "Choose App"))
                .font(.title3.weight(.semibold))

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 16)],
                    spacing: 18
                ) {
                    ForEach(apps) { app in
                        Button {
                            selectedAppPID = app.pid
                            showAppPicker = false
                        } label: {
                            VStack(spacing: 8) {
                                appIconView(app.icon, size: 48)
                                Text(app.name)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 96)
                            }
                            .frame(width: 104, height: 104)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(20)
        .frame(width: 540, height: 430)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 28, x: 0, y: 14)
    }

    @ViewBuilder
    private func appIconView(_ icon: NSImage?, size: CGFloat) -> some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app")
                .resizable()
                .frame(width: size, height: size)
        }
    }

    private var selectedApp: RunningApp? {
        guard let selectedAppPID else { return nil }
        return apps.first { $0.pid == selectedAppPID }
    }

    @ViewBuilder
    private var content: some View {
        if selectedAppPID == nil {
            ContentUnavailableView {
                Label(L10n.ru("Выберите приложение", en: "Choose App"), systemImage: "app.dashed")
            } description: {
                Text(L10n.ru("Выберите активное приложение, чтобы просматривать его логи.", en: "Select a running app to view its logs."))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selectedSection == .load {
            loadMonitoringContent
        } else if entries.isEmpty && isFetching {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.ru("Читаю логи приложения…", en: "Reading app logs…"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if entries.isEmpty {
            ContentUnavailableView {
                Label(L10n.ru("Нет записей", en: "No Entries"), systemImage: "tray")
            } description: {
                Text(lastError ?? L10n.ru("За выбранный период для этого приложения не найдено логов.", en: "No logs found for this app in the selected period."))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            logList
        }
    }

    @ViewBuilder
    private var loadMonitoringContent: some View {
        if let app = selectedApp {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    if settings.appLogsLoadSettings.contentMode.includesText {
                        appMetricCard(
                            title: L10n.ru("ЦПУ", en: "CPU"),
                            systemImage: "cpu",
                            color: .blue,
                            value: percentText(loadSession.selectedProcess?.cpuPercent ?? 0)
                        )
                        appMetricCard(
                            title: L10n.ru("ГПУ", en: "GPU"),
                            systemImage: "display",
                            color: .purple,
                            value: loadSession.selectedProcess?.gpuPercent.map { percentText($0) } ?? "—"
                        )
                        appMetricCard(
                            title: L10n.ru("ОЗУ", en: "RAM"),
                            systemImage: "memorychip",
                            color: .green,
                            value: memoryText(loadSession.selectedProcess?.memoryBytes ?? 0)
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Button {
                                toggleAppLoadRecording()
                            } label: {
                                Label(
                                    loadSession.isRecording ? L10n.ru("Остановить запись", en: "Stop Recording") : L10n.ru("Запись", en: "Record"),
                                    systemImage: loadSession.isRecording ? "stop.circle" : "record.circle"
                                )
                            }

                            Button {
                                exportAppLoad()
                            } label: {
                                Label(L10n.ru("Экспорт…", en: "Export…"), systemImage: "square.and.arrow.up")
                            }
                        }

                        if let message = loadSession.statusMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: 360, alignment: .leading)

                    Spacer()
                }
                .padding(.horizontal, 14)

                if let comparisonText = loadComparisonText {
                    HStack(spacing: 9) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .foregroundStyle(.secondary)
                        Text(comparisonText)
                            .font(.callout)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 14)
                }

                if settings.appLogsLoadSettings.contentMode.includesGraph {
                    LoadGraphsView(
                        systemHistory: loadSession.systemHistory,
                        processHistory: loadSession.selectedProcessHistory,
                        processName: app.name,
                        includeSystem: false,
                        graphResolution: settings.appLogsLoadSettings.graphResolution,
                        header: nil
                    )
                    .padding(.horizontal, 10)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyView()
        }
    }

    private var loadComparisonText: String? {
        guard let app = selectedApp,
              let currentCPU = loadSession.selectedProcess?.cpuPercent else {
            return nil
        }

        guard let percent = loadHistory.comparisonPercent(
            bundleID: app.bundleID,
            retentionDays: settings.loadHistoryRetentionDays,
            currentCPU: currentCPU
        ) else {
            return L10n.ru("Пока недостаточно истории нагрузки для сравнения.", en: "Not enough load history for comparison yet.")
        }

        let suspicious = loadSession.processes
            .filter { $0.cpuPercent >= 80 }
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(3)
            .map { "\($0.name) (\(String(format: "%.0f", $0.cpuPercent))%)" }

        let base: String
        if percent > 10 {
            base = L10n.ru("Сегодня программа работает на \(percent)% интенсивнее обычного.", en: "Today the app is \(percent)% more active than usual.")
        } else if percent < -10 {
            base = L10n.ru("Сегодня программа работает на \(abs(percent))% менее интенсивно, чем обычно.", en: "Today the app is \(abs(percent))% less active than usual.")
        } else {
            base = L10n.ru("Сегодня программа работает как обычно.", en: "Today the app is working as usual.")
        }

        guard !suspicious.isEmpty else { return base }
        return base + " Вот подозрительные процессы: \(suspicious.joined(separator: ", "))."
    }

    private func appMetricCard(
        title: String,
        systemImage: String,
        color: Color,
        value: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var logList: some View {
        List {
            ForEach(entries) { entry in
                LogRowView(entry: entry)
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(settings.background.isCustom ? .hidden : .visible)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func levelBinding(_ level: LogLevel) -> Binding<Bool> {
        Binding(
            get: { selectedLevels.contains(level) },
            set: { isOn in
                if isOn {
                    selectedLevels.insert(level)
                } else {
                    selectedLevels.remove(level)
                }
            }
        )
    }

    private func startLoadSessionIfNeeded() {
        guard let pid = selectedAppPID else {
            loadSession.stop()
            return
        }
        let header = selectedApp.map {
            LoadGraphHeader(
                title: $0.name,
                subtitle: L10n.ru("Версия: \($0.version ?? "—")", en: "Version: \($0.version ?? "—")"),
                timestamp: nil
            )
        }
        loadSession.start(
            settings: settings.appLogsLoadSettings,
            selectedPID: pid,
            recordAllProcesses: false,
            graphHeader: header
        )
    }

    private func toggleAppLoadRecording() {
        if loadSession.isRecording {
            loadSession.setRecording(false)
            return
        }

        if settings.appLogsLoadSettings.saveDirectoryPath == nil {
            guard chooseAppLoadDirectory() != nil else { return }
            loadSession.updateSettings(settings.appLogsLoadSettings)
        }
        loadSession.setRecording(true)
    }

    private func exportAppLoad() {
        guard loadSession.selectedProcess != nil else {
            loadError = L10n.ru("Пока нет данных о нагрузке выбранного приложения.", en: "No load data for the selected app yet.")
            return
        }

        switch settings.appLogsLoadSettings.contentMode {
        case .text:
            guard let url = savePanel(fileExtension: "csv", type: .commaSeparatedText) else { return }
            do {
                try loadSession.exportText(to: url)
            } catch {
                loadError = error.localizedDescription
            }
        case .graph:
            guard let url = savePanel(fileExtension: "png", type: .png) else { return }
            do {
                try loadSession.exportGraph(to: url)
            } catch {
                loadError = error.localizedDescription
            }
        case .both:
            guard let url = chooseAppLoadDirectory() else { return }
            do {
                try loadSession.exportBoth(to: url)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    @discardableResult
    private func chooseAppLoadDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.title = L10n.ru("Выберите папку для записей нагрузки", en: "Choose a folder for load recordings")
        panel.prompt = L10n.ru("Выбрать", en: "Choose")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        settings.appLogsLoadSettings.saveDirectoryPath = url.path
        return url
    }

    private func savePanel(fileExtension: String, type: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.title = L10n.ru("Экспорт нагрузки приложения", en: "Export App Load")
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

    private func loadRunningApps() {
        apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier > 0 }
            .map { app in
                let bundle = app.bundleURL.flatMap { Bundle(url: $0) }
                let version = (bundle?.infoDictionary?["CFBundleShortVersionString"] as? String)
                    ?? (bundle?.infoDictionary?["CFBundleVersion"] as? String)
                return RunningApp(
                    pid: app.processIdentifier,
                    name: app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? L10n.ru("Приложение", en: "App"),
                    bundleID: app.bundleIdentifier ?? "",
                    version: version,
                    icon: app.icon
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func reconcileSelectedPID() {
        guard let selectedAppPID,
              !apps.contains(where: { $0.pid == selectedAppPID }) else {
            return
        }
        self.selectedAppPID = nil
    }

    private func restartFetchLoop() {
        refreshTimer?.invalidate()
        entries.removeAll()

        guard let pid = selectedAppPID else { return }
        let seconds = max(refreshSeconds, 1)

        Task {
            await fetchOnce(pid: pid, windowSeconds: seconds)
        }

        let timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(seconds),
            repeats: true
        ) { _ in
            Task { @MainActor in
                await fetchOnce(pid: pid, windowSeconds: seconds)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func fetchOnce(pid: Int32, windowSeconds: Int) async {
        isFetching = true
        defer { isFetching = false }

        do {
            let loaded = try await AppLogReader.fetch(
                processID: pid,
                windowSeconds: windowSeconds,
                levels: selectedLevels
            )
            let existingIDs = Set(entries.map(\.id))
            let fresh = loaded.filter { !existingIDs.contains($0.id) }
            if !fresh.isEmpty {
                entries = Array(
                    (entries + fresh)
                        .sorted { $0.timestamp < $1.timestamp }
                        .suffix(1_000)
                )
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
