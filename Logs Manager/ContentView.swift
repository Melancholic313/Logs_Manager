import SwiftUI
import AppKit

struct RootView: View {
    @EnvironmentObject private var store: LogStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: BackgroundMonitor
    @EnvironmentObject private var logExplanation: LogExplanationPresenter
    @StateObject private var timeTravelStore = TimeTravelStore()

    @State private var selectedTab: LogTab? = .all
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var searchScope: LogSearchScope = .process
    @State private var appLogsSelectedPID: Int32?

    var body: some View {
        ZStack {
            mainContent

            if logExplanation.isPresented {
                LogExplanationOverlay()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: logExplanation.isPresented)
    }

    private var mainContent: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedTab)
                .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 320)
        } detail: {
            ZStack {
                settings.background.backgroundView

                VStack(spacing: 0) {
                    if settings.showSectionAnnotations {
                        SectionAnnotationView(text: (selectedTab ?? .all).annotation)
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                    }

                    Group {
                        if selectedTab == .settings {
                            SettingsView()
                        } else if selectedTab == .appLogs {
                            AppLogsView(selectedAppPID: $appLogsSelectedPID)
                        } else if selectedTab == .taskManager {
                            TaskManagerView()
                        } else if selectedTab == .timeTravel {
                            TimeTravelView(store: timeTravelStore)
                        } else if selectedTab == .recommendations {
                            RecommendationsView()
                        } else if selectedTab == .about {
                            AboutView()
                        } else if selectedTab == .stressTest {
                            StressTestView()
                        } else {
                            LogListView(
                                tab: selectedTab ?? .all,
                                searchText: $searchText,
                                searchScope: $searchScope
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 560)
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(settings.background.isCustom ? .dark : nil)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if showSearch {
                    Picker("", selection: $searchScope) {
                        ForEach(LogSearchScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 210)

                    TextField(L10n.ru("Поиск по логам", en: "Search logs"), text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 190)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearch.toggle()
                    }
                    if !showSearch {
                        searchText = ""
                    }
                } label: {
                    Label(L10n.ru("Поиск", en: "Search"), systemImage: "magnifyingglass")
                }
                .help(L10n.ru("Найти логи", en: "Find logs"))

                Button {
                    if showSearch {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSearch = false
                        }
                    }
                    store.refresh(windowMinutes: settings.windowMinutes)
                } label: {
                    Label(L10n.ru("Обновить", en: "Refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                if showSearch {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearch = false
                    }
                }
            }
        )
        .onAppear {
            renameDefaultSidebarItem()
            monitor.configure(settings: settings)
            if store.entries.isEmpty {
                store.refresh(windowMinutes: settings.windowMinutes)
            }
        }
        .onChange(of: settings.windowMinutes) { _, newValue in
            store.refresh(windowMinutes: newValue)
        }
    }

    private func renameDefaultSidebarItem() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for window in NSApp.windows {
                guard let toolbar = window.toolbar else { continue }
                for item in toolbar.items where item.itemIdentifier == .toggleSidebar {
                    item.label = L10n.ru("Показать меню", en: "Show Menu")
                    item.paletteLabel = L10n.ru("Показать меню", en: "Show Menu")
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(LogStore())
        .environmentObject(AppSettings())
        .environmentObject(BackgroundMonitor())
}
