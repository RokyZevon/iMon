import Foundation
import iMonCore

enum TestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

enum FakeProviderError: Error {
    case unavailable
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure.failed(message)
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    if actual != expected {
        throw TestFailure.failed("\(message): expected \(expected), got \(actual)")
    }
}

func testPercentageClampsIntoDisplayRange() throws {
    try expectEqual(Percentage(used: 150, total: 100).value, 100, "over-full percentage clamps")
    try expectEqual(Percentage(used: 0, total: 100).value, 0, "zero percentage")
    try expectEqual(Percentage(used: 50, total: 100).value, 50, "half percentage")
    try expectEqual(Percentage(used: 50, total: 0).value, 0, "zero total percentage")
}

func testByteFormatterUsesCompactBinaryUnits() throws {
    try expectEqual(MetricFormatter.bytes(0), "0 B", "zero bytes")
    try expectEqual(MetricFormatter.bytes(512), "512 B", "bytes below kilobyte")
    try expectEqual(MetricFormatter.bytes(1_536), "1.5 KB", "kilobytes")
    try expectEqual(MetricFormatter.bytes(1_572_864), "1.5 MB", "megabytes")
    try expectEqual(MetricFormatter.bytes(1_610_612_736), "1.5 GB", "gigabytes")
}

func testMenuTitleShowsCoreMetrics() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592),
        disk: DiskUsage(usedBytes: 50, totalBytes: 100),
        network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
    )

    try expectEqual(
        MetricFormatter.menuTitle(for: snapshot),
        "CPU 25% MEM 75% v 1.5 MB/s ^ 128 KB/s",
        "menu title"
    )
}

private final class FakeCPUProvider: CPUSampleProvider {
    var samples: [CPUTicks]

    init(_ samples: [CPUTicks]) {
        self.samples = samples
    }

    func sample() throws -> CPUTicks {
        samples.removeFirst()
    }
}

private final class FakeMemoryProvider: MemorySampleProvider {
    func sample() throws -> MemoryUsage {
        MemoryUsage(usedBytes: 4_294_967_296, totalBytes: 8_589_934_592)
    }
}

private final class FakeDiskProvider: DiskSampleProvider {
    func sample() throws -> DiskUsage {
        DiskUsage(usedBytes: 30, totalBytes: 100)
    }
}

private final class FakeNetworkProvider: NetworkSampleProvider {
    var samples: [NetworkCounters]

    init(_ samples: [NetworkCounters]) {
        self.samples = samples
    }

    func sample() throws -> NetworkCounters {
        samples.removeFirst()
    }
}

private final class IntermittentCPUProvider: CPUSampleProvider {
    var samples: [Result<CPUTicks, Error>]

    init(_ samples: [Result<CPUTicks, Error>]) {
        self.samples = samples
    }

    func sample() throws -> CPUTicks {
        switch samples.removeFirst() {
        case .success(let ticks):
            return ticks
        case .failure(let error):
            throw error
        }
    }
}

private final class IntermittentNetworkProvider: NetworkSampleProvider {
    var samples: [Result<NetworkCounters, Error>]

    init(_ samples: [Result<NetworkCounters, Error>]) {
        self.samples = samples
    }

    func sample() throws -> NetworkCounters {
        switch samples.removeFirst() {
        case .success(let counters):
            return counters
        case .failure(let error):
            throw error
        }
    }
}

func testFirstSampleUsesZeroDeltaBasedMetrics() throws {
    let sampler = SystemSampler(
        cpuProvider: FakeCPUProvider([CPUTicks(user: 10, system: 5, idle: 85)]),
        memoryProvider: FakeMemoryProvider(),
        diskProvider: FakeDiskProvider(),
        networkProvider: FakeNetworkProvider([NetworkCounters(receivedBytes: 1_000, transmittedBytes: 2_000)])
    )

    let snapshot = sampler.sample(now: Date(timeIntervalSince1970: 1))

    try expectEqual(snapshot.cpu.active, 0, "first CPU sample active")
    try expectEqual(snapshot.network.receiveBytesPerSecond, 0, "first receive rate")
    try expectEqual(snapshot.network.transmitBytesPerSecond, 0, "first transmit rate")
    try expectEqual(snapshot.memory.percentage, 50, "memory percentage")
    try expectEqual(snapshot.disk.percentage, 30, "disk percentage")
}

func testSecondSampleComputesCPUAndNetworkDeltas() throws {
    let sampler = SystemSampler(
        cpuProvider: FakeCPUProvider([
            CPUTicks(user: 100, system: 50, idle: 850),
            CPUTicks(user: 160, system: 90, idle: 950)
        ]),
        memoryProvider: FakeMemoryProvider(),
        diskProvider: FakeDiskProvider(),
        networkProvider: FakeNetworkProvider([
            NetworkCounters(receivedBytes: 1_000, transmittedBytes: 2_000),
            NetworkCounters(receivedBytes: 3_000, transmittedBytes: 2_500)
        ])
    )

    _ = sampler.sample(now: Date(timeIntervalSince1970: 1))
    let snapshot = sampler.sample(now: Date(timeIntervalSince1970: 3))

    try expectEqual(snapshot.cpu.user.rounded(), 30, "CPU user delta")
    try expectEqual(snapshot.cpu.system.rounded(), 20, "CPU system delta")
    try expectEqual(snapshot.cpu.idle.rounded(), 50, "CPU idle delta")
    try expectEqual(snapshot.cpu.active.rounded(), 50, "CPU active delta")
    try expectEqual(snapshot.network.receiveBytesPerSecond, 1_000, "receive rate")
    try expectEqual(snapshot.network.transmitBytesPerSecond, 250, "transmit rate")
}

func testCounterResetReturnsZeroRateForThatInterval() throws {
    let sampler = SystemSampler(
        cpuProvider: FakeCPUProvider([
            CPUTicks(user: 0, system: 0, idle: 1),
            CPUTicks(user: 0, system: 0, idle: 2)
        ]),
        memoryProvider: FakeMemoryProvider(),
        diskProvider: FakeDiskProvider(),
        networkProvider: FakeNetworkProvider([
            NetworkCounters(receivedBytes: 10_000, transmittedBytes: 20_000),
            NetworkCounters(receivedBytes: 5_000, transmittedBytes: 10_000)
        ])
    )

    _ = sampler.sample(now: Date(timeIntervalSince1970: 1))
    let snapshot = sampler.sample(now: Date(timeIntervalSince1970: 2))

    try expectEqual(snapshot.network.receiveBytesPerSecond, 0, "reset receive rate")
    try expectEqual(snapshot.network.transmitBytesPerSecond, 0, "reset transmit rate")
}

func testZeroCPUDeltaReturnsIdleFallback() throws {
    let sampler = SystemSampler(
        cpuProvider: FakeCPUProvider([
            CPUTicks(user: 100, system: 50, idle: 850),
            CPUTicks(user: 100, system: 50, idle: 850)
        ]),
        memoryProvider: FakeMemoryProvider(),
        diskProvider: FakeDiskProvider(),
        networkProvider: FakeNetworkProvider([
            NetworkCounters(receivedBytes: 1_000, transmittedBytes: 2_000),
            NetworkCounters(receivedBytes: 1_100, transmittedBytes: 2_100)
        ])
    )

    _ = sampler.sample(now: Date(timeIntervalSince1970: 1))
    let snapshot = sampler.sample(now: Date(timeIntervalSince1970: 2))

    try expectEqual(snapshot.cpu.active, 0, "zero total CPU active")
    try expectEqual(snapshot.cpu.idle, 100, "zero total CPU idle fallback")
}

func testNonPositiveElapsedTimeReturnsZeroNetworkRate() throws {
    let sampler = SystemSampler(
        cpuProvider: FakeCPUProvider([
            CPUTicks(user: 0, system: 0, idle: 1),
            CPUTicks(user: 1, system: 1, idle: 2)
        ]),
        memoryProvider: FakeMemoryProvider(),
        diskProvider: FakeDiskProvider(),
        networkProvider: FakeNetworkProvider([
            NetworkCounters(receivedBytes: 1_000, transmittedBytes: 2_000),
            NetworkCounters(receivedBytes: 3_000, transmittedBytes: 5_000)
        ])
    )

    _ = sampler.sample(now: Date(timeIntervalSince1970: 2))
    let snapshot = sampler.sample(now: Date(timeIntervalSince1970: 2))

    try expectEqual(snapshot.network.receiveBytesPerSecond, 0, "zero elapsed receive rate")
    try expectEqual(snapshot.network.transmitBytesPerSecond, 0, "zero elapsed transmit rate")
}

func testProviderFailureResetsDeltaBaselines() throws {
    let sampler = SystemSampler(
        cpuProvider: IntermittentCPUProvider([
            .success(CPUTicks(user: 100, system: 50, idle: 850)),
            .failure(FakeProviderError.unavailable),
            .success(CPUTicks(user: 200, system: 100, idle: 1_000))
        ]),
        memoryProvider: FakeMemoryProvider(),
        diskProvider: FakeDiskProvider(),
        networkProvider: IntermittentNetworkProvider([
            .success(NetworkCounters(receivedBytes: 10_000, transmittedBytes: 20_000)),
            .failure(FakeProviderError.unavailable),
            .success(NetworkCounters(receivedBytes: 30_000, transmittedBytes: 45_000))
        ])
    )

    _ = sampler.sample(now: Date(timeIntervalSince1970: 1))
    let failedSnapshot = sampler.sample(now: Date(timeIntervalSince1970: 2))
    let recoveredSnapshot = sampler.sample(now: Date(timeIntervalSince1970: 3))

    try expectEqual(failedSnapshot.cpu.active, 0, "failed CPU sample")
    try expectEqual(failedSnapshot.network.receiveBytesPerSecond, 0, "failed receive rate")
    try expectEqual(failedSnapshot.network.transmitBytesPerSecond, 0, "failed transmit rate")
    try expectEqual(recoveredSnapshot.cpu.active, 0, "recovered CPU sample uses fresh baseline")
    try expectEqual(recoveredSnapshot.network.receiveBytesPerSecond, 0, "recovered receive rate uses fresh baseline")
    try expectEqual(recoveredSnapshot.network.transmitBytesPerSecond, 0, "recovered transmit rate uses fresh baseline")
}

let tests: [(String, () throws -> Void)] = [
    ("percentage clamps into display range", testPercentageClampsIntoDisplayRange),
    ("byte formatter uses compact binary units", testByteFormatterUsesCompactBinaryUnits),
    ("menu title shows core metrics", testMenuTitleShowsCoreMetrics),
    ("first sample uses zero delta metrics", testFirstSampleUsesZeroDeltaBasedMetrics),
    ("second sample computes CPU and network deltas", testSecondSampleComputesCPUAndNetworkDeltas),
    ("counter reset returns zero rate", testCounterResetReturnsZeroRateForThatInterval),
    ("zero CPU delta returns idle fallback", testZeroCPUDeltaReturnsIdleFallback),
    ("non-positive elapsed time returns zero network rate", testNonPositiveElapsedTimeReturnsZeroNetworkRate),
    ("provider failure resets delta baselines", testProviderFailureResetsDeltaBaselines)
]

var failures: [String] = []

for (name, test) in tests {
    do {
        try test()
        print("PASS \(name)")
    } catch {
        failures.append("FAIL \(name): \(error)")
    }
}

if failures.isEmpty {
    print("All \(tests.count) self-tests passed")
} else {
    for failure in failures {
        print(failure)
    }
    exit(1)
}
