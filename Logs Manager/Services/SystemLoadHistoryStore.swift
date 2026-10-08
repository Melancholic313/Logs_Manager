import Foundation
import Combine

@MainActor
final class SystemLoadHistoryStore: ObservableObject {
    static let shared = SystemLoadHistoryStore()

    @Published private(set) var samples: [SystemLoadSample] = []
    @Published private(set) var isRunning = false

    private var timer: Timer?
    private var previousCPU: [Int32: UInt64] = [:]
    private var previousWall: UInt64?
    private var previousHost: HostCPUSample?
    private var isSamplingInFlight = false
    private var lastSampleDate = Date.distantPast

    func start() {
        guard !isRunning else { return }
        isRunning = true
        sampleNow()
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
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
        isRunning = false
    }

    func nearest(to date: Date) -> SystemLoadSample? {
        guard !samples.isEmpty else { return nil }
        return samples.min {
            abs($0.timestamp.timeIntervalSince(date))
                < abs($1.timestamp.timeIntervalSince(date))
        }
    }

    private func sampleNow() {
        guard !isSamplingInFlight else { return }
        if AppActivityState.shared.isLowPriority,
           Date().timeIntervalSince(lastSampleDate) < 30 {
            return
        }
        isSamplingInFlight = true

        let previousCPU = self.previousCPU
        let previousWall = self.previousWall
        let previousHost = self.previousHost

        Task { [weak self] in
            guard let self else { return }
            let snapshot = await Task.detached(
                priority: AppActivityState.shared.isLowPriority ? .background : .utility
            ) {
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
        lastSampleDate = Date()
        samples.append(snapshot.system)
        if samples.count > 720 {
            samples.removeFirst(samples.count - 720)
        }
    }
}
