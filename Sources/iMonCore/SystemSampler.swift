import Foundation

public final class SystemSampler {
    private let cpuProvider: CPUSampleProvider
    private let memoryProvider: MemorySampleProvider
    private let diskProvider: DiskSampleProvider
    private let networkProvider: NetworkSampleProvider
    private let cpuLoadProvider: CPULoadSampleProvider
    private var previousCPU: CPUTicks?
    private var previousNetwork: (counters: NetworkCounters, timestamp: Date)?

    public init(
        cpuProvider: CPUSampleProvider,
        memoryProvider: MemorySampleProvider,
        diskProvider: DiskSampleProvider,
        networkProvider: NetworkSampleProvider,
        cpuLoadProvider: CPULoadSampleProvider = StaticCPULoadProvider(load: .unknown)
    ) {
        self.cpuProvider = cpuProvider
        self.memoryProvider = memoryProvider
        self.diskProvider = diskProvider
        self.networkProvider = networkProvider
        self.cpuLoadProvider = cpuLoadProvider
    }

    public func sample(now: Date = Date()) -> SystemSnapshot {
        let cpuTicks = try? cpuProvider.sample()
        let networkCounters = try? networkProvider.sample()
        let cpuLoad = cpuLoadProvider.sample()
        let memory = (try? memoryProvider.sample()) ?? MemoryUsage(usedBytes: 0, totalBytes: 0)
        let disk = (try? diskProvider.sample()) ?? DiskUsage(usedBytes: 0, totalBytes: 0)

        let cpu: CPUUsage
        if let cpuTicks {
            cpu = cpuUsage(from: previousCPU, to: cpuTicks)
            previousCPU = cpuTicks
        } else {
            cpu = CPUUsage(user: 0, system: 0, idle: 100)
            previousCPU = nil
        }

        let network: NetworkRate
        if let networkCounters {
            network = networkRate(from: previousNetwork, to: networkCounters, now: now)
            previousNetwork = (networkCounters, now)
        } else {
            network = NetworkRate(receiveBytesPerSecond: 0, transmitBytesPerSecond: 0)
            previousNetwork = nil
        }

        return SystemSnapshot(timestamp: now, cpu: cpu, cpuLoad: cpuLoad, memory: memory, disk: disk, network: network)
    }

    private func cpuUsage(from previous: CPUTicks?, to current: CPUTicks) -> CPUUsage {
        guard let previous else {
            return CPUUsage(user: 0, system: 0, idle: 100)
        }

        let userDelta = current.user >= previous.user ? current.user - previous.user : 0
        let systemDelta = current.system >= previous.system ? current.system - previous.system : 0
        let idleDelta = current.idle >= previous.idle ? current.idle - previous.idle : 0
        let total = userDelta + systemDelta + idleDelta

        guard total > 0 else {
            return CPUUsage(user: 0, system: 0, idle: 100)
        }

        return CPUUsage(
            user: Double(userDelta) / Double(total) * 100,
            system: Double(systemDelta) / Double(total) * 100,
            idle: Double(idleDelta) / Double(total) * 100
        )
    }

    private func networkRate(
        from previous: (counters: NetworkCounters, timestamp: Date)?,
        to current: NetworkCounters,
        now: Date
    ) -> NetworkRate {
        guard let previous else {
            return NetworkRate(receiveBytesPerSecond: 0, transmitBytesPerSecond: 0)
        }

        let elapsed = now.timeIntervalSince(previous.timestamp)
        guard elapsed > 0 else {
            return NetworkRate(receiveBytesPerSecond: 0, transmitBytesPerSecond: 0)
        }

        let receivedDelta = current.receivedBytes >= previous.counters.receivedBytes
            ? current.receivedBytes - previous.counters.receivedBytes
            : 0
        let transmittedDelta = current.transmittedBytes >= previous.counters.transmittedBytes
            ? current.transmittedBytes - previous.counters.transmittedBytes
            : 0

        return NetworkRate(
            receiveBytesPerSecond: UInt64(Double(receivedDelta) / elapsed),
            transmitBytesPerSecond: UInt64(Double(transmittedDelta) / elapsed)
        )
    }
}

public struct StaticCPULoadProvider: CPULoadSampleProvider {
    private let load: CPULoadPressure

    public init(load: CPULoadPressure) {
        self.load = load
    }

    public func sample() -> CPULoadPressure {
        load
    }
}
