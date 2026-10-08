import SwiftUI
import AppKit
import Charts
import UniformTypeIdentifiers

struct StressTestView: View {
    @StateObject private var sampler = StatusMenuSampler()
    @State private var stressProcesses: [Process] = []
    @State private var isRunning = false
    @State private var lastVerdict: String?
    @State private var showGPUUnavailable = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                controls
                chart
                verdict
            }
            .padding(20)
        }
        .onAppear {
            sampler.start()
        }
        .onDisappear {
            stopStress()
            sampler.stop()
        }
        .alert(L10n.ru("GPU стресс-тест", en: "GPU Stress Test"), isPresented: $showGPUUnavailable) {
            Button(L10n.ru("ОК", en: "OK"), role: .cancel) {}
        } message: {
            Text(L10n.ru("Для GPU-стресса нужен отдельный бенчмарк или root-доступ. В этой сборке доступен CPU-стресс.", en: "GPU stress needs a dedicated benchmark or root access. This build supports CPU stress."))
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.ru("Стресс-тест", en: "Stress Test"))
                .font(.title2.weight(.semibold))

            HStack(spacing: 10) {
                Button(L10n.ru("CPU: одно ядро", en: "CPU: One Core")) {
                    startCPU(oneCore: true)
                }
                .disabled(isRunning)

                Button(L10n.ru("CPU: все ядра", en: "CPU: All Cores")) {
                    startCPU(oneCore: false)
                }
                .disabled(isRunning)

                Button(L10n.ru("GPU", en: "GPU")) {
                    showGPUUnavailable = true
                }
                .disabled(isRunning)

                Button(L10n.ru("Остановить", en: "Stop")) {
                    stopStress()
                }
                .disabled(!isRunning)
            }

            HStack(spacing: 10) {
                Button(L10n.ru("Экспорт отчёта", en: "Export Report")) {
                    exportReport()
                }
                .disabled(lastVerdict == nil)
            }
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.ru("Нагрузка CPU", en: "CPU Load"))
                .font(.headline)

            if sampler.cpuHistory.isEmpty {
                Text(L10n.ru("Ожидание данных…", en: "Waiting for data…"))
                    .foregroundStyle(.secondary)
            } else {
                Chart(Array(sampler.cpuHistory.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value(L10n.ru("Время", en: "Time"), index),
                        y: .value(L10n.ru("ЦПУ", en: "CPU"), value)
                    )
                    .foregroundStyle(Color.orange)
                }
                .frame(height: 180)
            }
        }
    }

    private var verdict: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.ru("Вердикт", en: "Verdict"))
                .font(.headline)

            if let lastVerdict {
                Text(lastVerdict)
                    .font(.system(size: 16))
                    .textSelection(.enabled)
            } else {
                Text(L10n.ru("Запустите стресс-тест, чтобы получить вердикт.", en: "Run a stress test to get a verdict."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startCPU(oneCore: Bool) {
        stopStress()
        let count = oneCore ? 1 : max(1, ProcessInfo.processInfo.activeProcessorCount)
        lastVerdict = nil

        for _ in 0..<count {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", "yes > /dev/null"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                stressProcesses.append(process)
            } catch {
                continue
            }
        }

        isRunning = !stressProcesses.isEmpty
    }

    private func stopStress() {
        for process in stressProcesses {
            process.terminate()
        }
        stressProcesses.removeAll()
        if isRunning {
            lastVerdict = L10n.ru("Тест завершён. Пиковая нагрузка CPU: \(String(format: "%.0f%%", sampler.cpuHistory.max() ?? 0)). Троттлинг-датчики недоступны в текущей сборке без root.", en: "Test finished. Peak CPU load: \(String(format: "%.0f%%", sampler.cpuHistory.max() ?? 0)). Throttling sensors are unavailable in this build without root.")
        }
        isRunning = false
    }

    private func exportReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = L10n.ru("Стресс-тест.txt", en: "Stress-Test.txt")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let text = lastVerdict ?? L10n.ru("Стресс-тест не выполнялся.", en: "No stress test was run.")
        try? text.data(using: .utf8)?.write(to: url, options: .atomic)
    }
}
