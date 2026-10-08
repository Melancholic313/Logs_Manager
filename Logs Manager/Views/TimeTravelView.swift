import SwiftUI

struct TimeTravelView: View {
    @ObservedObject var store: TimeTravelStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: BackgroundMonitor

    @State private var selectedLevels: Set<LogLevel> = [.default, .error, .fault, .info, .debug]
    @State private var playbackProgress: Double = 1
    @State private var isPlaying = false
    @State private var speedIndex = 1
    @State private var playTimer: Timer?

    private let speeds: [Double] = [1, 2, 5, 10, 60, 100]

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            content
        }
        .navigationTitle(L10n.ru("Путешествие во времени", en: "Time Travel"))
        .onAppear {
            monitor.stop()
            playbackProgress = 0
        }
        .onDisappear {
            stopPlayback()
            monitor.configure(settings: settings)
        }
        .onChange(of: store.startDate) { _, _ in
            periodChanged()
        }
        .onChange(of: store.endDate) { _, _ in
            periodChanged()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker(
                L10n.ru("Период от", en: "Period From"),
                selection: $store.startDate,
                displayedComponents: [.date, .hourAndMinute]
            )

            DatePicker(
                L10n.ru("Период до", en: "Period To"),
                selection: $store.endDate,
                displayedComponents: [.date, .hourAndMinute]
            )

            HStack {
                Button {
                    store.startAnalysis()
                    playbackProgress = 0
                } label: {
                    Label(L10n.ru("Начать путешествие", en: "Start Journey"), systemImage: "play.circle.fill")
                }

                Button(role: .destructive) {
                    stopPlayback()
                    store.stopAnalysis()
                } label: {
                    Label(L10n.ru("Остановить", en: "Stop"), systemImage: "stop.circle.fill")
                }

                Spacer()
            }

            HStack {
                Text(L10n.ru("Таймлайн", en: "Timeline"))
                    .font(.caption)
                Slider(value: $playbackProgress, in: 0...1)
                Text(playbackDate, style: .time)
                    .font(.caption.monospacedDigit())
            }

            HStack(spacing: 10) {
                Button {
                    togglePlayback()
                } label: {
                    Label(isPlaying ? L10n.ru("Пауза", en: "Pause") : L10n.ru("Проигрывать", en: "Play"), systemImage: isPlaying ? "pause.fill" : "play.fill")
                }
                .disabled(store.buckets.isEmpty)

                HStack(spacing: 8) {
                    Text(L10n.ru("Скорость", en: "Speed"))
                        .fixedSize()

                    Picker("", selection: $speedIndex) {
                        ForEach(speeds.indices, id: \.self) { index in
                            Text(String(format: "x%.0f", speeds[index])).tag(index)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }
            }
        }
        .padding(12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            periodCard

            HStack(spacing: 10) {
                Text(L10n.ru("Фильтр логов", en: "Log Filter"))
                    .font(.caption)
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
            .padding(.horizontal, 14)

            if store.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.ru("Загружаем и агрегируем данные периода…", en: "Loading and aggregating period data…"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.errorMessage {
                ContentUnavailableView {
                    Label(L10n.ru("Не удалось загрузить данные", en: "Failed to Load Data"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if store.buckets.isEmpty {
                ContentUnavailableView {
                    Label(L10n.ru("Путешествие не начато", en: "Journey Not Started"), systemImage: "clock.arrow.circlepath")
                } description: {
                    Text(L10n.ru("Выберите период и нажмите «Начать путешествие».", en: "Choose a period and press Start Journey."))
                }
            } else {
                logList
            }
        }
    }

    private var periodCard: some View {
        HStack(spacing: 14) {
            Text(L10n.ru("Период", en: "Period"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(store.startDate, style: .date)
                .monospacedDigit()
            Text(store.startDate, style: .time)
                .monospacedDigit()
            Text("—")
            Text(store.endDate, style: .date)
                .monospacedDigit()
            Text(store.endDate, style: .time)
                .monospacedDigit()
            Spacer()
            Text(L10n.ru("\(store.buckets.count) точек", en: "\(store.buckets.count) points"))
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 14)
    }

    private var playbackDate: Date {
        let duration = store.endDate.timeIntervalSince(store.startDate)
        guard duration > 0 else { return store.endDate }
        return store.startDate.addingTimeInterval(duration * playbackProgress)
    }

    private var visibleBuckets: [TimeTravelBucket] {
        guard let current = store.buckets.last(where: { $0.timestamp <= playbackDate }) else {
            return []
        }
        return [current]
    }

    private var displayEntries: [LogEntry] {
        visibleBuckets
            .flatMap(\.entries)
            .filter { selectedLevels.contains($0.messageType) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var logList: some View {
        List(displayEntries) { entry in
            LogRowView(entry: entry)
        }
        .id(visibleBuckets.first?.timestamp ?? playbackDate)
        .listStyle(.inset)
        .scrollContentBackground(settings.background.isCustom ? .hidden : .visible)
    }

    private func levelBinding(_ level: LogLevel) -> Binding<Bool> {
        Binding(
            get: { selectedLevels.contains(level) },
            set: { isOn in
                if isOn { selectedLevels.insert(level) } else { selectedLevels.remove(level) }
            }
        )
    }

    private func periodChanged() {
        stopPlayback()
        store.stopAnalysis()
        playbackProgress = 0
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard !store.buckets.isEmpty else { return }
        if playbackProgress >= 1 {
            playbackProgress = 0
        }
        isPlaying = true

        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [self] _ in
            advancePlayback()
        }
        playTimer = timer
    }

    private func advancePlayback() {
        guard isPlaying else { return }
        let speed = speeds[max(0, min(speedIndex, speeds.count - 1))]
        let duration = store.endDate.timeIntervalSince(store.startDate)
        guard duration > 0 else {
            stopPlayback()
            return
        }
        playbackProgress = min(1, playbackProgress + (speed * 0.5) / duration)
        if playbackProgress >= 1 {
            stopPlayback()
        }
    }

    private func stopPlayback() {
        playTimer?.invalidate()
        playTimer = nil
        isPlaying = false
    }

    private func memoryText(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}
