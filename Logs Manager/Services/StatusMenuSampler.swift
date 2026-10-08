import Foundation
import Combine

@MainActor
final class StatusMenuSampler: ObservableObject {
    @Published private(set) var system: SystemLoadSample?
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var topProcessName: String?

    private var timer: Timer?
    private var previousCPU: [Int32: UInt64] = [:]
    private var previousWall: UInt64?
    private var previousHost: HostCPUSample?
    private var isSamplingInFlight = false

    func start() {
        stop()
        sampleNow()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sampleNow()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sampleNow() {
        guard !isSamplingInFlight else { return }
        isSamplingInFlight = true

        let previousCPU = self.previousCPU
        let previousWall = self.previousWall
        let previousHost = self.previousHost

        Task { [weak self] in
            guard let self else { return }
            let snapshot = await Task.detached(priority: .utility) {
                ProcessMetricsReader.capture(
                    previousCPU: previousCPU,
                    previousGPU: [:],
                    previousHost: previousHost,
                    previousWall: previousWall
                )
            }.value
            self.apply(snapshot)
        }
    }

    private func apply(_ snapshot: ProcessMetricsSnapshot) {
        defer { isSamplingInFlight = false }

        previousCPU = snapshot.newCPU
        previousWall = snapshot.wallNanos
        previousHost = snapshot.host
        system = snapshot.system
        cpuHistory.append(snapshot.system.cpuPercent)
        if cpuHistory.count > 30 {
            cpuHistory.removeFirst(cpuHistory.count - 30)
        }
        topProcessName = snapshot.processes
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .first?
            .name
    }
}
