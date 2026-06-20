# iMon Menu Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight macOS menu bar app named iMon that monitors CPU, memory, disk, and network throughput.

**Architecture:** Use a Swift Package with a testable `iMonCore` library and an AppKit `iMon` executable. System metric calculations live behind provider protocols so deterministic tests can drive CPU/network delta math and snapshot aggregation.

**Tech Stack:** Swift Package Manager, Swift 6-compatible source, AppKit, Darwin/Mach APIs, SystemConfiguration-compatible POSIX network interfaces, executable self-test harness.

---

## File Structure

- Create `Package.swift`: package manifest with `iMonCore` library, `iMon` executable, and `iMonCoreSelfTests` executable.
- Create `Sources/iMonCore/Metrics.swift`: value models, percentage clamping, and byte formatting.
- Create `Sources/iMonCore/Providers.swift`: provider protocols and raw sample structs.
- Create `Sources/iMonCore/SystemSampler.swift`: stateful aggregation and CPU/network delta calculations.
- Create `Sources/iMonCore/MacOSProviders.swift`: concrete macOS providers using Darwin/Mach/FileManager APIs.
- Create `Sources/iMon/main.swift`: AppKit menu bar app and timer-driven rendering.
- Create `Sources/iMonCoreSelfTests/main.swift`: executable self-tests for formatting, model percentages, CPU/network deltas, macOS provider construction, and aggregate snapshots.
- Modify `README.md`: describe project, build/run/test commands, scope, and architecture.

## Task 1: Swift Package Skeleton and Failing Metric Tests

**Files:**
- Create: `Package.swift`
- Create: `Sources/iMonCore/Metrics.swift`
- Create: `Sources/iMonCoreSelfTests/main.swift`

- [ ] **Step 1: Write the failing metric tests**

Create `Sources/iMonCoreSelfTests/main.swift` with metric tests:

```swift
import Testing
@testable import iMonCore

struct MetricsTests {
    @Test func percentageClampsIntoDisplayRange() {
        #expect(Percentage(used: 150, total: 100).value == 100)
        #expect(Percentage(used: 0, total: 100).value == 0)
        #expect(Percentage(used: 50, total: 100).value == 50)
        #expect(Percentage(used: 50, total: 0).value == 0)
    }

    @Test func byteFormatterUsesCompactBinaryUnits() {
        #expect(MetricFormatter.bytes(0) == "0 B")
        #expect(MetricFormatter.bytes(512) == "512 B")
        #expect(MetricFormatter.bytes(1_536) == "1.5 KB")
        #expect(MetricFormatter.bytes(1_572_864) == "1.5 MB")
        #expect(MetricFormatter.bytes(1_610_612_736) == "1.5 GB")
    }

    @Test func menuTitleShowsCoreMetrics() {
        let snapshot = SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 10),
            cpu: CPUUsage(user: 10, system: 15, idle: 75),
            memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592),
            disk: DiskUsage(usedBytes: 50, totalBytes: 100),
            network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
        )

        #expect(MetricFormatter.menuTitle(for: snapshot) == "CPU 25% MEM 75% v 1.5 MB/s ^ 128 KB/s")
    }
}
```

- [ ] **Step 2: Add the minimal package manifest and empty source file**

Create `Package.swift`:

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "iMon",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "iMonCore", targets: ["iMonCore"]),
        .executable(name: "iMon", targets: ["iMon"])
    ],
    targets: [
        .target(name: "iMonCore"),
        .executableTarget(name: "iMon", dependencies: ["iMonCore"]),
        .executableTarget(name: "iMonCoreSelfTests", dependencies: ["iMonCore"])
    ],
    swiftLanguageModes: [.v6]
)
```

Create `Sources/iMonCore/Metrics.swift`:

```swift
import Foundation
```

- [ ] **Step 3: Run tests to verify RED**

Run: `swift run iMonCoreSelfTests`

Expected: FAIL because `Percentage`, `MetricFormatter`, `SystemSnapshot`, `CPUUsage`, `MemoryUsage`, `DiskUsage`, and `NetworkRate` are not defined.

- [ ] **Step 4: Implement metric models and formatting**

Replace `Sources/iMonCore/Metrics.swift` with:

```swift
import Foundation

public struct Percentage: Equatable {
    public let value: Double

    public init(used: Double, total: Double) {
        guard total > 0 else {
            self.value = 0
            return
        }
        self.value = min(100, max(0, used / total * 100))
    }
}

public struct CPUUsage: Equatable {
    public let user: Double
    public let system: Double
    public let idle: Double

    public init(user: Double, system: Double, idle: Double) {
        self.user = min(100, max(0, user))
        self.system = min(100, max(0, system))
        self.idle = min(100, max(0, idle))
    }

    public var active: Double {
        min(100, max(0, user + system))
    }
}

public struct MemoryUsage: Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64

    public init(usedBytes: UInt64, totalBytes: UInt64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }

    public var percentage: Double {
        Percentage(used: Double(usedBytes), total: Double(totalBytes)).value
    }
}

public struct DiskUsage: Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64

    public init(usedBytes: UInt64, totalBytes: UInt64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }

    public var percentage: Double {
        Percentage(used: Double(usedBytes), total: Double(totalBytes)).value
    }
}

public struct NetworkRate: Equatable {
    public let receiveBytesPerSecond: UInt64
    public let transmitBytesPerSecond: UInt64

    public init(receiveBytesPerSecond: UInt64, transmitBytesPerSecond: UInt64) {
        self.receiveBytesPerSecond = receiveBytesPerSecond
        self.transmitBytesPerSecond = transmitBytesPerSecond
    }
}

public struct SystemSnapshot: Equatable {
    public let timestamp: Date
    public let cpu: CPUUsage
    public let memory: MemoryUsage
    public let disk: DiskUsage
    public let network: NetworkRate

    public init(timestamp: Date, cpu: CPUUsage, memory: MemoryUsage, disk: DiskUsage, network: NetworkRate) {
        self.timestamp = timestamp
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
    }
}

public enum MetricFormatter {
    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    public static func bytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(value)) \(units[unitIndex])"
        }

        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return "\(Int(rounded)) \(units[unitIndex])"
        }
        return String(format: "%.1f %@", rounded, units[unitIndex])
    }

    public static func rate(_ bytesPerSecond: UInt64) -> String {
        "\(bytes(bytesPerSecond))/s"
    }

    public static func menuTitle(for snapshot: SystemSnapshot) -> String {
        "CPU \(percent(snapshot.cpu.active)) MEM \(percent(snapshot.memory.percentage)) v \(rate(snapshot.network.receiveBytesPerSecond)) ^ \(rate(snapshot.network.transmitBytesPerSecond))"
    }
}
```

- [ ] **Step 5: Run tests to verify GREEN**

Run: `swift run iMonCoreSelfTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/iMonCore/Metrics.swift Sources/iMonCoreSelfTests/main.swift
git commit -m "feat: add metric models and formatting"
```

## Task 2: Provider Protocols and Sampler Delta Logic

**Files:**
- Create: `Sources/iMonCore/Providers.swift`
- Create: `Sources/iMonCore/SystemSampler.swift`
- Modify: `Sources/iMonCoreSelfTests/main.swift`

- [ ] **Step 1: Write failing sampler tests**

Append sampler tests to `Sources/iMonCoreSelfTests/main.swift`:

```swift
import Testing
@testable import iMonCore

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

struct SystemSamplerTests {
    @Test func firstSampleUsesZeroDeltaBasedMetrics() {
        let sampler = SystemSampler(
            cpuProvider: FakeCPUProvider([CPUTicks(user: 10, system: 5, idle: 85)]),
            memoryProvider: FakeMemoryProvider(),
            diskProvider: FakeDiskProvider(),
            networkProvider: FakeNetworkProvider([NetworkCounters(receivedBytes: 1_000, transmittedBytes: 2_000)])
        )

        let snapshot = sampler.sample(now: Date(timeIntervalSince1970: 1))

        #expect(snapshot.cpu.active == 0)
        #expect(snapshot.network.receiveBytesPerSecond == 0)
        #expect(snapshot.network.transmitBytesPerSecond == 0)
        #expect(snapshot.memory.percentage == 50)
        #expect(snapshot.disk.percentage == 30)
    }

    @Test func secondSampleComputesCPUAndNetworkDeltas() {
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

        #expect(snapshot.cpu.user.rounded() == 30)
        #expect(snapshot.cpu.system.rounded() == 20)
        #expect(snapshot.cpu.idle.rounded() == 50)
        #expect(snapshot.cpu.active.rounded() == 50)
        #expect(snapshot.network.receiveBytesPerSecond == 1_000)
        #expect(snapshot.network.transmitBytesPerSecond == 250)
    }

    @Test func counterResetReturnsZeroRateForThatInterval() {
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

        #expect(snapshot.network.receiveBytesPerSecond == 0)
        #expect(snapshot.network.transmitBytesPerSecond == 0)
    }
}
```

- [ ] **Step 2: Run tests to verify RED**

Run: `swift run iMonCoreSelfTests`

Expected: FAIL because provider protocols, raw samples, and `SystemSampler` are not defined.

- [ ] **Step 3: Implement provider protocols**

Create `Sources/iMonCore/Providers.swift`:

```swift
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

public protocol MemorySampleProvider {
    func sample() throws -> MemoryUsage
}

public protocol DiskSampleProvider {
    func sample() throws -> DiskUsage
}

public protocol NetworkSampleProvider {
    func sample() throws -> NetworkCounters
}
```

- [ ] **Step 4: Implement sampler**

Create `Sources/iMonCore/SystemSampler.swift`:

```swift
import Foundation

public final class SystemSampler {
    private let cpuProvider: CPUSampleProvider
    private let memoryProvider: MemorySampleProvider
    private let diskProvider: DiskSampleProvider
    private let networkProvider: NetworkSampleProvider
    private var previousCPU: CPUTicks?
    private var previousNetwork: (counters: NetworkCounters, timestamp: Date)?

    public init(
        cpuProvider: CPUSampleProvider,
        memoryProvider: MemorySampleProvider,
        diskProvider: DiskSampleProvider,
        networkProvider: NetworkSampleProvider
    ) {
        self.cpuProvider = cpuProvider
        self.memoryProvider = memoryProvider
        self.diskProvider = diskProvider
        self.networkProvider = networkProvider
    }

    public func sample(now: Date = Date()) -> SystemSnapshot {
        let cpuTicks = (try? cpuProvider.sample()) ?? CPUTicks(user: 0, system: 0, idle: 0)
        let networkCounters = (try? networkProvider.sample()) ?? NetworkCounters(receivedBytes: 0, transmittedBytes: 0)
        let memory = (try? memoryProvider.sample()) ?? MemoryUsage(usedBytes: 0, totalBytes: 0)
        let disk = (try? diskProvider.sample()) ?? DiskUsage(usedBytes: 0, totalBytes: 0)

        let cpu = cpuUsage(from: previousCPU, to: cpuTicks)
        let network = networkRate(from: previousNetwork, to: networkCounters, now: now)

        previousCPU = cpuTicks
        previousNetwork = (networkCounters, now)

        return SystemSnapshot(timestamp: now, cpu: cpu, memory: memory, disk: disk, network: network)
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
```

- [ ] **Step 5: Run tests to verify GREEN**

Run: `swift run iMonCoreSelfTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/iMonCore/Providers.swift Sources/iMonCore/SystemSampler.swift Sources/iMonCoreSelfTests/main.swift
git commit -m "feat: add system sampler"
```

## Task 3: macOS Concrete Providers

**Files:**
- Create: `Sources/iMonCore/MacOSProviders.swift`
- Modify: `Sources/iMonCore/SystemSampler.swift`

- [ ] **Step 1: Write a failing construction test**

Append to `Sources/iMonCoreSelfTests/main.swift`:

```swift
struct MacOSProviderConstructionTests {
    @Test func defaultSamplerCanBeConstructed() {
        let sampler = SystemSampler.live()
        let snapshot = sampler.sample(now: Date(timeIntervalSince1970: 1))

        #expect(snapshot.cpu.active >= 0)
        #expect(snapshot.memory.totalBytes >= 0)
        #expect(snapshot.disk.totalBytes >= 0)
    }
}
```

- [ ] **Step 2: Run test to verify RED**

Run: `swift run iMonCoreSelfTests`

Expected: FAIL because `SystemSampler.live()` is not defined.

- [ ] **Step 3: Implement live providers**

Create `Sources/iMonCore/MacOSProviders.swift` with concrete provider types:

```swift
import Darwin
import Foundation
import MachO

public struct MacOSCPUProvider: CPUSampleProvider {
    public init() {}

    public func sample() throws -> CPUTicks {
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
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
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(Int(cpuInfoCount) * MemoryLayout<integer_t>.stride)
            )
        }

        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        let stride = Int(CPU_STATE_MAX)

        for cpu in 0..<Int(processorCount) {
            let base = cpu * stride
            user += UInt64(cpuInfo[base + Int(CPU_STATE_USER)])
            system += UInt64(cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            system += UInt64(cpuInfo[base + Int(CPU_STATE_NICE)])
            idle += UInt64(cpuInfo[base + Int(CPU_STATE_IDLE)])
        }

        return CPUTicks(user: user, system: system, idle: idle)
    }
}

public struct MacOSMemoryProvider: MemorySampleProvider {
    public init() {}

    public func sample() throws -> MemoryUsage {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            throw POSIXError(.EIO)
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = UInt64(pageSize)
        let usedPages = UInt64(stats.active_count + stats.inactive_count + stats.wire_count + stats.compressor_page_count)
        let total = ProcessInfo.processInfo.physicalMemory

        return MemoryUsage(usedBytes: usedPages * page, totalBytes: total)
    }
}

public struct MacOSDiskProvider: DiskSampleProvider {
    private let url: URL

    public init(url: URL = URL(fileURLWithPath: "/")) {
        self.url = url
    }

    public func sample() throws -> DiskUsage {
        let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        let total = UInt64(max(values.volumeTotalCapacity ?? 0, 0))
        let available = UInt64(max(values.volumeAvailableCapacityForImportantUsage ?? 0, 0))
        let used = total >= available ? total - available : 0

        return DiskUsage(usedBytes: used, totalBytes: total)
    }
}

public struct MacOSNetworkProvider: NetworkSampleProvider {
    public init() {}

    public func sample() throws -> NetworkCounters {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            throw POSIXError(.EIO)
        }

        defer { freeifaddrs(pointer) }

        var received: UInt64 = 0
        var transmitted: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first

        while let current = cursor {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp, !isLoopback, current.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK),
               let data = current.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                received += UInt64(networkData.ifi_ibytes)
                transmitted += UInt64(networkData.ifi_obytes)
            }

            cursor = current.pointee.ifa_next
        }

        return NetworkCounters(receivedBytes: received, transmittedBytes: transmitted)
    }
}
```

- [ ] **Step 4: Add live sampler factory**

Append to `Sources/iMonCore/SystemSampler.swift`:

```swift
public extension SystemSampler {
    static func live() -> SystemSampler {
        SystemSampler(
            cpuProvider: MacOSCPUProvider(),
            memoryProvider: MacOSMemoryProvider(),
            diskProvider: MacOSDiskProvider(),
            networkProvider: MacOSNetworkProvider()
        )
    }
}
```

- [ ] **Step 5: Run tests and build**

Run: `swift run iMonCoreSelfTests`

Expected: PASS.

Run: `swift build`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/iMonCore/MacOSProviders.swift Sources/iMonCore/SystemSampler.swift Sources/iMonCoreSelfTests/main.swift
git commit -m "feat: add macOS metric providers"
```

## Task 4: AppKit Menu Bar Executable

**Files:**
- Create: `Sources/iMon/main.swift`

- [ ] **Step 1: Write a failing build check**

Create `Sources/iMon/main.swift`:

```swift
import AppKit
import iMonCore

_ = MenuBarController.self
```

- [ ] **Step 2: Run build to verify RED**

Run: `swift build`

Expected: FAIL because `MenuBarController` is not defined.

- [ ] **Step 3: Implement menu bar app**

Replace `Sources/iMon/main.swift` with:

```swift
import AppKit
import Foundation
import iMonCore

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let sampler: SystemSampler
    private let menu = NSMenu()
    private let cpuItem = NSMenuItem()
    private let memoryItem = NSMenuItem()
    private let diskItem = NSMenuItem()
    private let downloadItem = NSMenuItem()
    private let uploadItem = NSMenuItem()
    private var timer: Timer?

    init(statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
         sampler: SystemSampler = .live()) {
        self.statusItem = statusItem
        self.sampler = sampler
        super.init()
        configureMenu()
    }

    func start() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func configureMenu() {
        statusItem.button?.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        statusItem.menu = menu

        menu.addItem(cpuItem)
        menu.addItem(memoryItem)
        menu.addItem(diskItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(downloadItem)
        menu.addItem(uploadItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit iMon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func update() {
        let snapshot = sampler.sample()
        statusItem.button?.title = MetricFormatter.menuTitle(for: snapshot)
        cpuItem.title = "CPU: \(MetricFormatter.percent(snapshot.cpu.active))"
        memoryItem.title = "Memory: \(MetricFormatter.percent(snapshot.memory.percentage)) (\(MetricFormatter.bytes(snapshot.memory.usedBytes)) / \(MetricFormatter.bytes(snapshot.memory.totalBytes)))"
        diskItem.title = "Disk: \(MetricFormatter.percent(snapshot.disk.percentage)) (\(MetricFormatter.bytes(snapshot.disk.usedBytes)) / \(MetricFormatter.bytes(snapshot.disk.totalBytes)))"
        downloadItem.title = "Download: \(MetricFormatter.rate(snapshot.network.receiveBytesPerSecond))"
        uploadItem.title = "Upload: \(MetricFormatter.rate(snapshot.network.transmitBytesPerSecond))"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = MenuBarController()
        controller?.start()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 4: Run build to verify GREEN**

Run: `swift build`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/iMon/main.swift
git commit -m "feat: add menu bar app"
```

## Task 5: README and Full Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write README content**

Replace `README.md`:

```markdown
# iMon

iMon is a lightweight open source macOS menu bar monitor inspired by iStat. This first release monitors CPU, memory, disk usage, and network throughput.

## Tech Stack

- Swift Package Manager
- Swift + AppKit for the menu bar application
- Native macOS/Darwin APIs for metric collection
- Executable self-test harness for core metric tests

## Build

```bash
swift build
```

## Run

```bash
swift run iMon
```

The app appears in the macOS menu bar and uses accessory activation policy.

## Test

```bash
swift run iMonCoreSelfTests
```

## Scope

Implemented:

- CPU usage
- Memory usage
- Disk usage for the root volume
- Network receive/transmit throughput

Out of scope for this first release:

- Sensors, fans, GPU, battery, process lists, charts, preferences, login items, signing, and notarized app packaging

## Architecture

`iMonCore` contains metric models, formatting, provider protocols, and the stateful sampler. The `iMon` executable owns the AppKit status item and timer. UI code only consumes snapshots from the core sampler.
```

- [ ] **Step 2: Run full verification**

Run: `swift run iMonCoreSelfTests`

Expected: PASS.

Run: `swift build`

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add usage instructions"
```

## Task 6: Final Review and Completion Prep

**Files:**
- Inspect all changed files.

- [ ] **Step 1: Review requirement coverage**

Check:

```bash
git status --short
git log --oneline --decorate -8
rg -n "TO""DO|TB""D|fatalError|force unwrap|try!" Package.swift Sources Tests README.md docs/superpowers
swift run iMonCoreSelfTests
swift build
```

Expected:

- Working tree clean except intentional ignored build artifacts.
- Recent history contains commits for `.gitignore`, design, plan, implementation, and README.
- No unfinished markers.
- No avoidable `fatalError` or `try!`.
- Tests and build pass.

- [ ] **Step 2: Keep branch and worktree**

Do not merge, discard, push, or open a PR. Preserve:

- Branch: `codex/imon-menu-monitor`
- Worktree: `/Users/rokyzevon/dev/projects/iMon/.worktrees/imon-menu-monitor`

- [ ] **Step 3: Final report**

Report in Chinese:

- Chosen stack: Swift + AppKit + Swift Package Manager.
- Implemented CPU, memory, disk, and network monitoring.
- Run commands: `swift build`, `swift run iMonCoreSelfTests`, `swift run iMon`.
- Verification output summary.
- Branch and worktree path.
- Residual risks: unsigned/unpackaged executable, no charts/preferences/login item, first sample has zero delta-based CPU/network values.
