import Foundation
import Darwin

struct ProcessMetricSample: Identifiable, Sendable, Equatable {
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let gpuPercent: Double?
    let memoryBytes: UInt64
    let timestamp: Date

    var id: Int32 { pid }

    var historyPoint: LoadHistoryPoint {
        LoadHistoryPoint(
            timestamp: timestamp,
            cpu: cpuPercent,
            gpu: gpuPercent ?? 0,
            memoryBytes: memoryBytes
        )
    }
}

struct SystemLoadSample: Sendable, Equatable {
    let timestamp: Date
    let cpuPercent: Double
    let gpuPercent: Double
    let memoryUsedBytes: UInt64
    let memoryTotalBytes: UInt64

    var historyPoint: LoadHistoryPoint {
        LoadHistoryPoint(
            timestamp: timestamp,
            cpu: cpuPercent,
            gpu: gpuPercent,
            memoryBytes: memoryUsedBytes
        )
    }
}

struct LoadHistoryPoint: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let cpu: Double
    let gpu: Double
    let memoryBytes: UInt64

    init(id: UUID = UUID(), timestamp: Date, cpu: Double, gpu: Double, memoryBytes: UInt64) {
        self.id = id
        self.timestamp = timestamp
        self.cpu = cpu
        self.gpu = gpu
        self.memoryBytes = memoryBytes
    }

    var memoryMB: Double {
        Double(memoryBytes) / 1_048_576
    }
}

struct HostCPUSample: Sendable {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64
}

struct ProcessMetricsSnapshot: Sendable {
    let processes: [ProcessMetricSample]
    let system: SystemLoadSample
    let newCPU: [Int32: UInt64]
    let newGPU: [Int32: UInt64]
    let host: HostCPUSample
    let wallNanos: UInt64
}

enum ProcessMetricsReader {
    nonisolated static func capture(
        previousCPU: [Int32: UInt64],
        previousGPU: [Int32: UInt64],
        previousHost: HostCPUSample?,
        previousWall: UInt64?
    ) -> ProcessMetricsSnapshot {
        let wall = DispatchTime.now().uptimeNanoseconds
        let elapsedNanos: UInt64? = previousWall.flatMap { wall >= $0 ? wall - $0 : nil }
        let host = Self.hostCPUSample()
        let systemCPU = Self.systemCPUPercent(previous: previousHost, current: host)
        let memory = Self.systemMemory()
        let timestamp = Date()

        var processes: [ProcessMetricSample] = []
        var newCPU: [Int32: UInt64] = [:]
        var newGPU: [Int32: UInt64] = [:]

        for pid in Self.allPIDs() {
            guard pid > 0 else { continue }

            var usage = rusage_info_v4()
            let rusageResult: Int32 = withUnsafeMutablePointer(to: &usage) { usagePointer in
                usagePointer.withMemoryRebound(
                    to: rusage_info_t?.self,
                    capacity: MemoryLayout<rusage_info_v4>.size / MemoryLayout<rusage_info_t?>.size
                ) { bufferPointer in
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, bufferPointer)
                }
            }

            let totalCPUTicks: UInt64?
            if rusageResult == 0 {
                totalCPUTicks = usage.ri_user_time + usage.ri_system_time
            } else {
                totalCPUTicks = nil
            }

            let cpuPercent: Double
            if let current = totalCPUTicks,
               let previous = previousCPU[pid],
               let elapsedNanos,
               elapsedNanos > 0 {
                let delta = current >= previous ? current - previous : 0
                cpuPercent = min(max(Double(delta) / Double(elapsedNanos) * 100.0, 0), 999)
            } else {
                cpuPercent = 0
            }

            if let current = totalCPUTicks {
                newCPU[pid] = current
            }

            let gpu = Self.gpuTicks(for: pid)
            let gpuPercent: Double?
            if let current = gpu,
               let previous = previousGPU[pid],
               let elapsedNanos,
               elapsedNanos > 0 {
                let delta = current >= previous ? current - previous : 0
                gpuPercent = min(max(Double(delta) / Double(elapsedNanos) * 100.0, 0), 100)
            } else {
                gpuPercent = nil
            }

            if let current = gpu {
                newGPU[pid] = current
            }

            let memoryBytes = rusageResult == 0 ? usage.ri_phys_footprint : 0
            let name = Self.processName(for: pid)

            processes.append(
                ProcessMetricSample(
                    pid: pid,
                    name: name,
                    cpuPercent: cpuPercent,
                    gpuPercent: gpuPercent,
                    memoryBytes: memoryBytes,
                    timestamp: timestamp
                )
            )
        }

        let gpuTotal = processes
            .compactMap(\.gpuPercent)
            .reduce(0, +)
        let systemGPU = min(max(gpuTotal, 0), 100)

        let system = SystemLoadSample(
            timestamp: timestamp,
            cpuPercent: systemCPU,
            gpuPercent: systemGPU,
            memoryUsedBytes: memory.used,
            memoryTotalBytes: memory.total
        )

        return ProcessMetricsSnapshot(
            processes: processes,
            system: system,
            newCPU: newCPU,
            newGPU: newGPU,
            host: host,
            wallNanos: wall
        )
    }

    nonisolated private static func allPIDs() -> [Int32] {
        let capacity = 8192
        var pids = [Int32](repeating: 0, count: capacity)
        let byteCount = pids.withUnsafeMutableBufferPointer { buffer -> Int32 in
            proc_listpids(
                UInt32(PROC_ALL_PIDS),
                0,
                buffer.baseAddress,
                Int32(buffer.count * MemoryLayout<Int32>.size)
            )
        }

        guard byteCount > 0 else { return [] }
        let count = min(Int(byteCount) / MemoryLayout<Int32>.size, capacity)
        return Array(pids.prefix(count)).filter { $0 > 0 }
    }

    nonisolated private static func processName(for pid: Int32) -> String {
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let pathLength = pathBuffer.withUnsafeMutableBufferPointer { buffer in
            proc_pidpath(pid, buffer.baseAddress, UInt32(buffer.count))
        }
        if pathLength > 0 {
            let path = pathBuffer.withUnsafeBufferPointer { buffer in
                String(cString: buffer.baseAddress!)
            }
            let name = URL(fileURLWithPath: path).lastPathComponent
            if !name.isEmpty {
                return name
            }
        }

        var nameBuffer = [CChar](repeating: 0, count: 256)
        let nameLength = nameBuffer.withUnsafeMutableBufferPointer { buffer in
            proc_name(pid, buffer.baseAddress, UInt32(buffer.count))
        }
        if nameLength > 0 {
            let name = nameBuffer.withUnsafeBufferPointer { buffer in
                String(cString: buffer.baseAddress!)
            }
            if !name.isEmpty {
                return name
            }
        }

        return "PID \(pid)"
    }

    nonisolated private static func gpuTicks(for pid: Int32) -> UInt64? {
        var task = mach_port_name_t()
        let taskResult = task_name_for_pid(mach_task_self_, pid, &task)
        guard taskResult == KERN_SUCCESS else { return nil }

        var info = task_power_info_v2_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_power_info_v2_data_t>.size / MemoryLayout<natural_t>.size
        )

        let infoResult = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(
                    task,
                    task_flavor_t(TASK_POWER_INFO_V2),
                    intPointer,
                    &count
                )
            }
        }

        mach_port_deallocate(mach_task_self_, task)

        guard infoResult == KERN_SUCCESS else { return nil }
        return info.gpu_energy.task_gpu_utilisation
    }

    nonisolated private static func hostCPUSample() -> HostCPUSample {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(
                    mach_host_self(),
                    HOST_CPU_LOAD_INFO,
                    intPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return HostCPUSample(user: 0, system: 0, idle: 0, nice: 0)
        }

        return HostCPUSample(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    nonisolated private static func systemCPUPercent(
        previous: HostCPUSample?,
        current: HostCPUSample
    ) -> Double {
        guard let previous else { return 0 }

        let previousBusy = previous.user + previous.system + previous.nice
        let currentBusy = current.user + current.system + current.nice
        let busyDelta = currentBusy >= previousBusy ? currentBusy - previousBusy : 0
        let idleDelta = current.idle >= previous.idle ? current.idle - previous.idle : 0
        let totalDelta = busyDelta + idleDelta

        guard totalDelta > 0 else { return 0 }
        return min(max(Double(busyDelta) / Double(totalDelta) * 100.0, 0), 100)
    }

    nonisolated private static func systemMemory() -> (used: UInt64, total: UInt64) {
        let total = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    intPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, total)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        return (active + wired + compressed, total)
    }
}
