import Foundation

public struct CPUTicks: Equatable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
    }
}

public struct NetworkCounters: Equatable {
    public let receivedBytes: UInt64
    public let transmittedBytes: UInt64

    public init(receivedBytes: UInt64, transmittedBytes: UInt64) {
        self.receivedBytes = receivedBytes
        self.transmittedBytes = transmittedBytes
    }
}

public protocol CPUSampleProvider {
    func sample() throws -> CPUTicks
}

public protocol CPULoadSampleProvider {
    func sample() -> CPULoadPressure
}

public protocol MemorySampleProvider {
    func sample() throws -> MemoryUsage
}

public protocol MemoryPressureSampleProvider {
    func sample() -> MemoryPressureLevel
}

public protocol DiskSampleProvider {
    func sample() throws -> DiskUsage
}

public protocol NetworkSampleProvider {
    func sample() throws -> NetworkCounters
}
