import SwiftUI
import AppKit
import Charts

struct StatusMenuView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: BackgroundMonitor
    @StateObject private var sampler = StatusMenuSampler()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Logs Manager")
                .font(.headline)

            miniStats

            Toggle(
                L10n.ru("Мониторинг в фоне", en: "Background Monitoring"),
                isOn: Binding(
                    get: { settings.backgroundMonitoringEnabled },
                    set: { newValue in
                        settings.backgroundMonitoringEnabled = newValue
                        monitor.configure(settings: settings)
                    }
                )
            )
            .toggleStyle(.checkbox)

            if monitor.isRunning {
                Label(L10n.ru("Мониторинг активен", en: "Monitoring Active"), systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let accessMessage = monitor.accessMessage {
                Text(accessMessage)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !monitor.recentAlerts.isEmpty {
                Divider()
                Text(L10n.ru("Последние события", en: "Recent Events"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(monitor.recentAlerts.prefix(5)) { alert in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: alert.level.iconName)
                            .foregroundStyle(alert.level.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.title)
                                .font(.callout.weight(.semibold))
                            Text(alert.body)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            Button(L10n.ru("Открыть приложение", en: "Open App")) {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
                AppActivityState.shared.refresh()
            }

            Button(L10n.ru("Выйти", en: "Quit")) {
                AppDelegate.shouldTerminateOnQuit = true
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 320)
        .onAppear {
            monitor.configure(settings: settings)
            sampler.start()
        }
        .onDisappear {
            sampler.stop()
        }
    }

    private var miniStats: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.ru("ЦПУ", en: "CPU"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", sampler.system?.cpuPercent ?? 0))
                        .font(.headline)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.ru("ОЗУ", en: "RAM"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(memoryText(sampler.system?.memoryUsedBytes ?? 0))
                        .font(.headline)
                        .monospacedDigit()
                }

                if let top = sampler.topProcessName {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.ru("Активный", en: "Active"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(top)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            if !sampler.cpuHistory.isEmpty {
                Chart(Array(sampler.cpuHistory.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value(L10n.ru("Время", en: "Time"), index),
                        y: .value(L10n.ru("ЦПУ", en: "CPU"), value)
                    )
                    .foregroundStyle(Color.blue)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 48)
            }
        }
        .padding(.vertical, 2)
    }

    private func memoryText(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}
