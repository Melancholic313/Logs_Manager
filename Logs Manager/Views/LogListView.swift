import SwiftUI

struct LogListView: View {
    let tab: LogTab
    @Binding var searchText: String
    @Binding var searchScope: LogSearchScope

    @EnvironmentObject private var store: LogStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            if store.isLoading && store.entries.isEmpty {
                LoadingLogsView(progress: store.progress)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = store.errorMessage, store.entries.isEmpty {
                ContentUnavailableView {
                    Label(L10n.ru("Не удалось загрузить логи", en: "Failed to Load Logs"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button(L10n.ru("Повторить", en: "Retry")) {
                        store.refresh(windowMinutes: settings.windowMinutes)
                    }
                }
            } else if groups.isEmpty {
                ContentUnavailableView {
                    Label(L10n.ru("Нет подходящих записей", en: "No Matching Entries"), systemImage: "tray")
                } description: {
                    Text(L10n.ru("За последние \(settings.windowMinutes) минут в этой категории не найдено событий.", en: "No events found in this category for the last \(settings.windowMinutes) minutes."))
                }
            } else {
                logList
            }
        }
        .navigationTitle(tab.title)
    }

    private var filteredEntries: [LogEntry] {
        store.entries(
            for: tab,
            includeDebugInfo: settings.showDebugInfo,
            searchText: searchText,
            searchScope: searchScope
        )
    }

    private var groups: [LogGroup] {
        if tab == .all,
           searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cache = settings.showDebugInfo ? store.allLogGroupsWithDebug : store.allLogGroups
            if !cache.isEmpty {
                return cache
            }
        }
        if tab == .dangerousPatterns,
           searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !store.dangerousLogGroups.isEmpty {
            return store.dangerousLogGroups
        }
        return LogHumanizer.group(filteredEntries)
    }

    private var logList: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        LogRowView(entry: entry)
                    }
                } header: {
                    groupHeader(group)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(settings.background.isCustom ? .hidden : .visible)
        .safeAreaInset(edge: .bottom) {
            statusBar
        }
    }

    private func groupHeader(_ group: LogGroup) -> some View {
        HStack(spacing: 6) {
            Image(systemName: LogHumanizer.groupIcon(subsystem: group.subsystem))
            Text(LogHumanizer.groupTitle(subsystem: group.subsystem, category: group.category))
            Spacer()
            Text("\(group.entries.count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.headline)
        .textCase(nil)
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            if let lastUpdated = store.lastUpdated {
                Label(
                    L10n.ru("Обновлено \(LogHumanizer.timeLabel(for: lastUpdated))", en: "Updated \(LogHumanizer.timeLabel(for: lastUpdated))"),
                    systemImage: "clock"
                )
            } else {
                Text(L10n.ru("Журнал ещё не загружен", en: "Log not loaded yet"))
            }

            if store.isLoading {
                Spacer()
                StatusProgressBar(progress: store.progress)
                    .frame(width: 220)
                Spacer()
            } else {
                Spacer()
            }

            Text("\(filteredEntries.count) записей")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct StatusProgressBar: View {
    let progress: LogLoadProgress?

    @State private var shimmering = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                if let progress, let total = progress.total, total > 0 {
                    let fraction = min(max(CGFloat(progress.processed) / CGFloat(total), 0), 1)
                    Capsule()
                        .fill(gradient)
                        .frame(width: proxy.size.width * fraction)
                        .animation(.easeOut(duration: 0.18), value: progress.processed)
                } else {
                    Capsule()
                        .fill(gradient)
                        .frame(width: proxy.size.width * 0.30)
                        .offset(x: shimmering ? proxy.size.width * 0.70 : 0)
                }
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: true)) {
                shimmering = true
            }
        }
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
