import Darwin
@preconcurrency import Dispatch
import Foundation

public struct MacOSCPUProvider: CPUSampleProvider {
    public init() {}

    public func sample() throws -> CPUTicks {
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }

        let result = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &cpuInfo,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            throw POSIXError(.EIO)
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: cpuInfo)),
                vm_size_t(Int(cpuInfoCount) * MemoryLayout<integer_t>.stride)
            )
        }

        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        let stride = Int(CPU_STATE_MAX)

        for cpu in 0..<Int(processorCount) {
            let base = cpu * stride
            user += Self.tickValue(cpuInfo[base + Int(CPU_STATE_USER)])
            user += Self.tickValue(cpuInfo[base + Int(CPU_STATE_NICE)])
            system += Self.tickValue(cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            idle += Self.tickValue(cpuInfo[base + Int(CPU_STATE_IDLE)])
        }

        return CPUTicks(user: user, system: system, idle: idle)
    }

    private static func tickValue(_ value: integer_t) -> UInt64 {
        UInt64(UInt32(bitPattern: Int32(value)))
    }
}

public struct MacOSCPULoadProvider: CPULoadSampleProvider {
    public init() {}

    public func sample() -> CPULoadPressure {
        var loads = [Double](repeating: 0, count: 1)
        guard getloadavg(&loads, 1) == 1 else {
            return .unknown
        }

        return CPULoadPressure(
            oneMinuteLoad: loads[0],
            activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount
        )
    }
}

public final class MacOSMemoryPressureProvider: MemoryPressureSampleProvider, @unchecked Sendable {
    private let lock = NSLock()
    private let source: any DispatchSourceMemoryPressure
    private var currentLevel: MemoryPressureLevel

    public init(initialLevel: MemoryPressureLevel = .normal) {
        self.currentLevel = initialLevel
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: .all,
            queue: DispatchQueue(label: "iMon.memory-pressure")
        )
        self.source = source

        source.setEventHandler { [weak self, weak source] in
            guard let source else {
                return
            }
            self?.updateLevel(from: source.data)
        }
        source.resume()
    }

    deinit {
        source.cancel()
    }

    public func sample() -> MemoryPressureLevel {
        lock.lock()
        defer { lock.unlock() }
        return currentLevel
    }

    public static func level(for event: DispatchSource.MemoryPressureEvent) -> MemoryPressureLevel {
        if event.contains(.critical) {
            return .critical
        }
        if event.contains(.warning) {
            return .warning
        }
        if event.contains(.normal) {
            return .normal
        }
        return .unknown
    }

    private func updateLevel(from event: DispatchSource.MemoryPressureEvent) {
        let level = Self.level(for: event)
        lock.lock()
        currentLevel = level
        lock.unlock()
    }
}

public final class MacOSMemoryProvider: MemorySampleProvider {
    private let pressureProvider: MemoryPressureSampleProvider

    public init(pressureProvider: MemoryPressureSampleProvider = MacOSMemoryPressureProvider()) {
        self.pressureProvider = pressureProvider
    }

    public func sample() throws -> MemoryUsage {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(host, HOST_VM_INFO64, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            throw POSIXError(.EIO)
        }

        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS else {
            throw POSIXError(.EIO)
        }

        let page = UInt64(pageSize)
        let usedPages = UInt64(stats.active_count + stats.inactive_count + stats.wire_count + stats.compressor_page_count)
        let total = ProcessInfo.processInfo.physicalMemory

        return MemoryUsage(usedBytes: usedPages * page, totalBytes: total, pressure: pressureProvider.sample())
    }
}

public struct MacOSDiskProvider: DiskSampleProvider {
    private let url: URL

    public init(url: URL = URL(fileURLWithPath: "/")) {
        self.url = url
    }

    public func sample() throws -> DiskUsage {
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: url.path)
        let total = (attributes[.systemSize] as? NSNumber)?.uint64Value ?? 0
        let available = (attributes[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
        let used = total >= available ? total - available : 0

        return DiskUsage(usedBytes: used, totalBytes: total)
    }
}

public struct MacOSNetworkProvider: NetworkSampleProvider {
    public init() {}

    public func sample() throws -> NetworkCounters {
        var received: UInt64 = 0
        var transmitted: UInt64 = 0
        let count = try interfaceCount()

        guard count > 0 else {
            return NetworkCounters(receivedBytes: 0, transmittedBytes: 0)
        }

        for row in 1...count {
            guard let data = interfaceData(row: row), shouldCount(data) else {
                continue
            }

            received += data.ifmd_data.ifi_ibytes
            transmitted += data.ifmd_data.ifi_obytes
        }

        return NetworkCounters(receivedBytes: received, transmittedBytes: transmitted)
    }

    private func interfaceCount() throws -> Int {
        var count: Int32 = 0
        var length = MemoryLayout<Int32>.stride
        var mib = [
            Int32(CTL_NET),
            Int32(PF_LINK),
            Int32(NETLINK_GENERIC),
            Int32(IFMIB_SYSTEM),
            Int32(IFMIB_IFCOUNT)
        ]

        guard sysctl(&mib, u_int(mib.count), &count, &length, nil, 0) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        return max(0, Int(count))
    }

    private func interfaceData(row: Int) -> ifmibdata? {
        var data = ifmibdata()
        var length = MemoryLayout<ifmibdata>.stride
        var mib = [
            Int32(CTL_NET),
            Int32(PF_LINK),
            Int32(NETLINK_GENERIC),
            Int32(IFMIB_IFDATA),
            Int32(row),
            Int32(IFDATA_GENERAL)
        ]

        guard sysctl(&mib, u_int(mib.count), &data, &length, nil, 0) == 0 else {
            return nil
        }

        return data
    }

    private func shouldCount(_ data: ifmibdata) -> Bool {
        let flags = data.ifmd_flags
        let isUp = (flags & UInt32(IFF_UP)) != 0
        let isRunning = (flags & UInt32(IFF_RUNNING)) != 0
        let isLoopback = (flags & UInt32(IFF_LOOPBACK)) != 0
        let name = interfaceName(data)
        let excludedPrefixes = ["awdl", "bridge", "gif", "llw", "lo", "stf", "utun"]

        return isUp && isRunning && !isLoopback && !excludedPrefixes.contains { name.hasPrefix($0) }
    }

    private func interfaceName(_ data: ifmibdata) -> String {
        var name = data.ifmd_name
        let capacity = MemoryLayout.size(ofValue: name)
        return withUnsafePointer(to: &name) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: capacity) { rebound in
                String(cString: rebound)
            }
        }
    }
}

public extension SystemSampler {
    static func live() -> SystemSampler {
        SystemSampler(
            cpuProvider: MacOSCPUProvider(),
            memoryProvider: MacOSMemoryProvider(),
            diskProvider: MacOSDiskProvider(),
            networkProvider: MacOSNetworkProvider(),
            cpuLoadProvider: MacOSCPULoadProvider()
        )
    }
}
