import SwiftUI
import Combine

@MainActor
final class LogStore: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var progress: LogLoadProgress?
    @Published private(set) var allLogGroups: [LogGroup] = []
    @Published private(set) var allLogGroupsWithDebug: [LogGroup] = []
    @Published private(set) var dangerousLogGroups: [LogGroup] = []

    func refresh(windowMinutes: Int = 15) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        progress = LogLoadProgress(processed: 0, total: nil)

        Task {
            do {
                let loaded = try await LogReader.load(window: "\(windowMinutes)m") { progress in
                    Task { @MainActor in
                        self.progress = progress
                    }
                }
                entries = loaded
                allLogGroups = LogHumanizer.group(
                    loaded.filter { $0.messageType.isVisibleByDefault }
                )
                allLogGroupsWithDebug = LogHumanizer.group(loaded)
                dangerousLogGroups = LogHumanizer.group(loaded.filter(\.isDangerous))
                lastUpdated = Date()
            } catch {
                errorMessage = error.localizedDescription
            }
            progress = nil
            isLoading = false
        }
    }

    func entries(
        for tab: LogTab,
        includeDebugInfo: Bool,
        searchText: String,
        searchScope: LogSearchScope
    ) -> [LogEntry] {
        entries.filter { entry in
            let isLevelVisible = includeDebugInfo
                || entry.messageType.isVisibleByDefault
                || tab == .dangerousPatterns
            guard isLevelVisible else {
                return false
            }

            switch tab {
            case .all:
                return true
            case .errors:
                return entry.messageType == .error
            case .critical:
                return entry.messageType == .fault
            case .dangerousPatterns:
                return entry.isDangerous
            case .appLogs:
                return true
            case .taskManager:
                return true
            case .timeTravel:
                return true
            case .recommendations:
                return true
            case .about:
                return true
            case .stressTest:
                return true
            case .processes:
                return matches(entry, subsystems: processSubsystems, categories: processCategories)
            case .security:
                return matches(entry, subsystems: securitySubsystems, categories: securityCategories)
            case .network:
                return matches(entry, subsystems: networkSubsystems, categories: networkCategories)
            case .power:
                return matches(entry, subsystems: powerSubsystems, categories: powerCategories)
            case .settings:
                return true
            }
        }
        .filter { entry in
            matchesSearch(entry, query: searchText, scope: searchScope)
        }
    }

    private func matchesSearch(
        _ entry: LogEntry,
        query: String,
        scope: LogSearchScope
    ) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        switch scope {
        case .process:
            return entry.processName.localizedCaseInsensitiveContains(trimmed)
        case .title:
            let humanizedTitle = LogHumanizer.humanizedSentence(for: entry)
            let groupTitle = LogHumanizer.groupTitle(
                subsystem: entry.subsystem,
                category: entry.category
            )
            let haystack = "\(humanizedTitle) \(groupTitle)"
            return haystack.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func matches(
        _ entry: LogEntry,
        subsystems: [String],
        categories: [String]
    ) -> Bool {
        let subsystem = entry.subsystem.lowercased()
        let category = entry.category.lowercased()
        return subsystems.contains { subsystem.contains($0) }
            || categories.contains { category.contains($0) }
    }

    private let processSubsystems = [
        "runningboard", "launchservices", "windowserver", "coreduet",
        "coreservices", "xpc", "process", "scheduler"
    ]
    private let processCategories = [
        "process", "lifecycle", "assertion", "launch", "exit", "crash", "termination"
    ]

    private let securitySubsystems = [
        "securityd", "coreauthd", "accountsd", "tcc", "sandbox",
        "keychain", "auth", "appleaccount"
    ]
    private let securityCategories = [
        "security", "auth", "keychain", "tcc", "sandbox", "account", "privacy"
    ]

    private let networkSubsystems = [
        "network", "wifi", "bluetooth", "socket", "dns", "cfnetwork",
        "mdnsresponder", "rapport", "nesessionmanager"
    ]
    private let networkCategories = [
        "network", "connection", "socket", "dns", "wifi", "bluetooth", "web"
    ]

    private let powerSubsystems = [
        "powerd", "battery", "energy", "thermal", "iokit", "powermanagement",
        "brightness", "display"
    ]
    private let powerCategories = [
        "power", "battery", "energy", "thermal", "brightness", "displaystate"
    ]
}
