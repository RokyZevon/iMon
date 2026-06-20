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

let tests: [(String, () throws -> Void)] = [
    ("percentage clamps into display range", testPercentageClampsIntoDisplayRange),
    ("byte formatter uses compact binary units", testByteFormatterUsesCompactBinaryUnits),
    ("menu title shows core metrics", testMenuTitleShowsCoreMetrics)
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
