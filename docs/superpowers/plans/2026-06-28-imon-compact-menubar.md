# iMon Compact Menu Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the wide single-line menu bar title with configurable compact stacked values: CPU above memory, upload above download, with per-row menu toggles.

**Architecture:** Keep the existing Swift Package + AppKit status item architecture. Put testable formatting and settings behavior in `iMonCore`, add a tiny `iMonApp` helper target for AppKit attributed-title construction, and keep `Sources/iMon/main.swift` as thin UI wiring over tested helpers.

**Tech Stack:** Swift 6, Swift Package Manager, AppKit `NSStatusItem`/`NSStatusBarButton`, Foundation `UserDefaults`, executable self-test target.

---

## File Structure

- Modify `Package.swift`: add an `iMonApp` library target that depends on `iMonCore`; make `iMon` and `iMonCoreSelfTests` depend on `iMonApp`.
- Modify `Sources/iMonCore/Metrics.swift`: keep existing metric models and add compact network rate formatting.
- Create `Sources/iMonCore/MenuBarDisplay.swift`: define menu bar display metrics, settings, `UserDefaults` storage, and pure stacked-title formatting.
- Create `Sources/iMonApp/MenuBarAttributedTitle.swift`: convert the pure stacked title into an AppKit `NSAttributedString` for `NSStatusBarButton.attributedTitle`.
- Modify `Sources/iMon/main.swift`: replace the old wide title string with attributed stacked title rendering, add menu checkmarks, toggle actions, and settings persistence.
- Modify `Sources/iMonCoreSelfTests/main.swift`: add self-tests for compact rate formatting, settings defaults/toggling/persistence, stacked title order/fallback, and attributed title string generation.

## Task 1: Core Compact Rate And Stacked Title Model

**Files:**
- Modify: `Sources/iMonCore/Metrics.swift`
- Create: `Sources/iMonCore/MenuBarDisplay.swift`
- Modify: `Sources/iMonCoreSelfTests/main.swift`

- [ ] **Step 1: Write failing tests for compact network rates and stacked title order**

Add these test functions to `Sources/iMonCoreSelfTests/main.swift` after `testByteFormatterUsesCompactBinaryUnits()`:

```swift
func testCompactRateFormatterOmitsPerSecondForMenuBar() throws {
    try expectEqual(MetricFormatter.compactRate(0), "0B", "zero compact rate")
    try expectEqual(MetricFormatter.compactRate(512), "512B", "byte compact rate")
    try expectEqual(MetricFormatter.compactRate(1_024), "1K", "one kilobyte compact rate")
    try expectEqual(MetricFormatter.compactRate(131_072), "128K", "kilobyte compact rate")
    try expectEqual(MetricFormatter.compactRate(1_572_864), "1.5M", "megabyte compact rate")
    try expectEqual(MetricFormatter.compactRate(1_610_612_736), "1.5G", "gigabyte compact rate")
}

func testStackedMenuTitleUsesCPUOverMemoryAndUploadOverDownload() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592),
        disk: DiskUsage(usedBytes: 50, totalBytes: 100),
        network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
    )

    let title = MenuBarTitleFormatter.stackedTitle(for: snapshot, settings: .defaults)

    try expectEqual(title.topLine, "CPU 25%  ↑ 128K", "top line")
    try expectEqual(title.bottomLine, "MEM 75%  ↓ 1.5M", "bottom line")
    try expectEqual(title.stringValue, "CPU 25%  ↑ 128K\nMEM 75%  ↓ 1.5M", "stacked title string")
}

func testStackedMenuTitleFallsBackWhenEveryRowIsHidden() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592),
        disk: DiskUsage(usedBytes: 50, totalBytes: 100),
        network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
    )
    let settings = MenuBarDisplaySettings(
        showsCPU: false,
        showsMemory: false,
        showsUpload: false,
        showsDownload: false,
        showsDisk: false
    )

    let title = MenuBarTitleFormatter.stackedTitle(for: snapshot, settings: settings)

    try expectEqual(title.topLine, "iMon", "fallback top line")
    try expectEqual(title.bottomLine, "", "fallback bottom line")
    try expectEqual(title.stringValue, "iMon", "fallback title string")
}
```

Add these test entries to the `tests` array immediately after `"byte formatter uses compact binary units"`:

```swift
    ("compact rate formatter omits per-second for menu bar", testCompactRateFormatterOmitsPerSecondForMenuBar),
    ("stacked menu title uses CPU over memory and upload over download", testStackedMenuTitleUsesCPUOverMemoryAndUploadOverDownload),
    ("stacked menu title falls back when every row is hidden", testStackedMenuTitleFallsBackWhenEveryRowIsHidden),
```

- [ ] **Step 2: Run test to verify RED**

Run:

```bash
swift run iMonCoreSelfTests
```

Expected: compile failure that mentions missing symbols such as `MetricFormatter.compactRate`, `MenuBarTitleFormatter`, or `MenuBarDisplaySettings`.

- [ ] **Step 3: Add minimal core implementation**

In `Sources/iMonCore/Metrics.swift`, add this method inside `public enum MetricFormatter`, before `rate(_:)`:

```swift
    public static func compactRate(_ bytesPerSecond: UInt64) -> String {
        let units = ["B", "K", "M", "G", "T"]
        var value = Double(bytesPerSecond)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(value))\(units[unitIndex])"
        }

        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return "\(Int(rounded))\(units[unitIndex])"
        }
        return String(format: "%.1f%@", rounded, units[unitIndex])
    }
```

Create `Sources/iMonCore/MenuBarDisplay.swift` with this content:

```swift
import Foundation

public enum MenuBarDisplayMetric: String, CaseIterable, Equatable {
    case cpu
    case memory
    case upload
    case download
    case disk
}

public struct MenuBarDisplaySettings: Equatable {
    public var showsCPU: Bool
    public var showsMemory: Bool
    public var showsUpload: Bool
    public var showsDownload: Bool
    public var showsDisk: Bool

    public init(
        showsCPU: Bool,
        showsMemory: Bool,
        showsUpload: Bool,
        showsDownload: Bool,
        showsDisk: Bool
    ) {
        self.showsCPU = showsCPU
        self.showsMemory = showsMemory
        self.showsUpload = showsUpload
        self.showsDownload = showsDownload
        self.showsDisk = showsDisk
    }

    public static let defaults = MenuBarDisplaySettings(
        showsCPU: true,
        showsMemory: true,
        showsUpload: true,
        showsDownload: true,
        showsDisk: false
    )

    public func isVisible(_ metric: MenuBarDisplayMetric) -> Bool {
        switch metric {
        case .cpu:
            return showsCPU
        case .memory:
            return showsMemory
        case .upload:
            return showsUpload
        case .download:
            return showsDownload
        case .disk:
            return showsDisk
        }
    }
}

public struct MenuBarStackedTitle: Equatable {
    public let topLine: String
    public let bottomLine: String

    public init(topLine: String, bottomLine: String) {
        self.topLine = topLine
        self.bottomLine = bottomLine
    }

    public var stringValue: String {
        if bottomLine.isEmpty {
            return topLine
        }
        return "\(topLine)\n\(bottomLine)"
    }
}

public enum MenuBarTitleFormatter {
    public static func stackedTitle(
        for snapshot: SystemSnapshot,
        settings: MenuBarDisplaySettings
    ) -> MenuBarStackedTitle {
        var columns: [(top: String, bottom: String)] = []

        let cpuMemoryColumn = column(
            top: settings.showsCPU ? "CPU \(MetricFormatter.percent(snapshot.cpu.active))" : "",
            bottom: settings.showsMemory ? "MEM \(MetricFormatter.percent(snapshot.memory.percentage))" : ""
        )
        if let cpuMemoryColumn {
            columns.append(cpuMemoryColumn)
        }

        let networkColumn = column(
            top: settings.showsUpload ? "↑ \(MetricFormatter.compactRate(snapshot.network.transmitBytesPerSecond))" : "",
            bottom: settings.showsDownload ? "↓ \(MetricFormatter.compactRate(snapshot.network.receiveBytesPerSecond))" : ""
        )
        if let networkColumn {
            columns.append(networkColumn)
        }

        guard !columns.isEmpty else {
            return MenuBarStackedTitle(topLine: "iMon", bottomLine: "")
        }

        return MenuBarStackedTitle(
            topLine: columns.map(\.top).joined(separator: "  "),
            bottomLine: columns.map(\.bottom).joined(separator: "  ").trimmingCharacters(in: .whitespaces)
        )
    }

    private static func column(top: String, bottom: String) -> (top: String, bottom: String)? {
        guard !top.isEmpty || !bottom.isEmpty else {
            return nil
        }

        let width = max(top.count, bottom.count)
        return (
            top: top.padding(toLength: width, withPad: " ", startingAt: 0),
            bottom: bottom.padding(toLength: width, withPad: " ", startingAt: 0)
        )
    }
}
```

- [ ] **Step 4: Run test to verify GREEN**

Run:

```bash
swift run iMonCoreSelfTests
```

Expected: all self-tests pass, with the final line showing the increased test count.

- [ ] **Step 5: Commit Task 1**

```bash
git add Sources/iMonCore/Metrics.swift Sources/iMonCore/MenuBarDisplay.swift Sources/iMonCoreSelfTests/main.swift
git commit -m "feat: add compact menu bar title model"
```

## Task 2: Display Settings Toggle And UserDefaults Persistence

**Files:**
- Modify: `Sources/iMonCore/MenuBarDisplay.swift`
- Modify: `Sources/iMonCoreSelfTests/main.swift`

- [ ] **Step 1: Write failing tests for toggles and persistence**

Add these helpers and tests to `Sources/iMonCoreSelfTests/main.swift` after `testStackedMenuTitleFallsBackWhenEveryRowIsHidden()`:

```swift
func makeIsolatedDefaults(name: String) -> UserDefaults {
    let suiteName = "iMonCoreSelfTests.\(name).\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Unable to create isolated UserDefaults suite")
    }
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

func testMenuBarDisplaySettingsDefaultRows() throws {
    let settings = MenuBarDisplaySettings.defaults

    try expect(settings.isVisible(.cpu), "CPU visible by default")
    try expect(settings.isVisible(.memory), "memory visible by default")
    try expect(settings.isVisible(.upload), "upload visible by default")
    try expect(settings.isVisible(.download), "download visible by default")
    try expect(!settings.isVisible(.disk), "disk hidden by default")
}

func testMenuBarDisplaySettingsToggleChangesOnlySelectedMetric() throws {
    var settings = MenuBarDisplaySettings.defaults

    settings.toggle(.upload)

    try expect(settings.isVisible(.cpu), "CPU remains visible")
    try expect(settings.isVisible(.memory), "memory remains visible")
    try expect(!settings.isVisible(.upload), "upload toggled off")
    try expect(settings.isVisible(.download), "download remains visible")
    try expect(!settings.isVisible(.disk), "disk remains hidden")
}

func testMenuBarDisplaySettingsStorePersistsRows() throws {
    let defaults = makeIsolatedDefaults(name: "display-store")
    let store = MenuBarDisplaySettingsStore(defaults: defaults, keyPrefix: "testMenuBar")
    var settings = MenuBarDisplaySettings.defaults
    settings.toggle(.cpu)
    settings.toggle(.disk)

    store.save(settings)
    let loaded = store.load()

    try expectEqual(loaded, settings, "loaded settings")
}
```

Add these entries to the `tests` array after `"stacked menu title falls back when every row is hidden"`:

```swift
    ("menu bar display settings default rows", testMenuBarDisplaySettingsDefaultRows),
    ("menu bar display settings toggle changes only selected metric", testMenuBarDisplaySettingsToggleChangesOnlySelectedMetric),
    ("menu bar display settings store persists rows", testMenuBarDisplaySettingsStorePersistsRows),
```

- [ ] **Step 2: Run test to verify RED**

Run:

```bash
swift run iMonCoreSelfTests
```

Expected: compile failure mentioning missing `toggle(_:)` or `MenuBarDisplaySettingsStore`.

- [ ] **Step 3: Add minimal toggle and store implementation**

In `Sources/iMonCore/MenuBarDisplay.swift`, add this method inside `public struct MenuBarDisplaySettings` after `isVisible(_:)`:

```swift
    public mutating func toggle(_ metric: MenuBarDisplayMetric) {
        switch metric {
        case .cpu:
            showsCPU.toggle()
        case .memory:
            showsMemory.toggle()
        case .upload:
            showsUpload.toggle()
        case .download:
            showsDownload.toggle()
        case .disk:
            showsDisk.toggle()
        }
    }
```

Add this type to the bottom of `Sources/iMonCore/MenuBarDisplay.swift`:

```swift
public struct MenuBarDisplaySettingsStore {
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "menuBarDisplay") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func load() -> MenuBarDisplaySettings {
        MenuBarDisplaySettings(
            showsCPU: bool(for: .cpu, defaultValue: MenuBarDisplaySettings.defaults.showsCPU),
            showsMemory: bool(for: .memory, defaultValue: MenuBarDisplaySettings.defaults.showsMemory),
            showsUpload: bool(for: .upload, defaultValue: MenuBarDisplaySettings.defaults.showsUpload),
            showsDownload: bool(for: .download, defaultValue: MenuBarDisplaySettings.defaults.showsDownload),
            showsDisk: bool(for: .disk, defaultValue: MenuBarDisplaySettings.defaults.showsDisk)
        )
    }

    public func save(_ settings: MenuBarDisplaySettings) {
        defaults.set(settings.showsCPU, forKey: key(for: .cpu))
        defaults.set(settings.showsMemory, forKey: key(for: .memory))
        defaults.set(settings.showsUpload, forKey: key(for: .upload))
        defaults.set(settings.showsDownload, forKey: key(for: .download))
        defaults.set(settings.showsDisk, forKey: key(for: .disk))
    }

    private func bool(for metric: MenuBarDisplayMetric, defaultValue: Bool) -> Bool {
        let key = key(for: metric)
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }

    private func key(for metric: MenuBarDisplayMetric) -> String {
        "\(keyPrefix).\(metric.rawValue)"
    }
}
```

- [ ] **Step 4: Run test to verify GREEN**

Run:

```bash
swift run iMonCoreSelfTests
```

Expected: all self-tests pass.

- [ ] **Step 5: Commit Task 2**

```bash
git add Sources/iMonCore/MenuBarDisplay.swift Sources/iMonCoreSelfTests/main.swift
git commit -m "feat: persist menu bar display settings"
```

## Task 3: AppKit Attributed Title Helper

**Files:**
- Modify: `Package.swift`
- Create: `Sources/iMonApp/MenuBarAttributedTitle.swift`
- Modify: `Sources/iMonCoreSelfTests/main.swift`

- [ ] **Step 1: Write failing test for attributed title string**

In `Sources/iMonCoreSelfTests/main.swift`, add this import next to existing imports:

```swift
import iMonApp
```

Add this test after `testMenuBarDisplaySettingsStorePersistsRows()`:

```swift
func testMenuBarAttributedTitleUsesStackedTitleString() throws {
    let stackedTitle = MenuBarStackedTitle(
        topLine: "CPU 25%  ↑ 128K",
        bottomLine: "MEM 75%  ↓ 1.5M"
    )

    let attributedTitle = MenuBarAttributedTitleFactory.attributedTitle(for: stackedTitle)

    try expectEqual(attributedTitle.string, "CPU 25%  ↑ 128K\nMEM 75%  ↓ 1.5M", "attributed title string")
    try expect(attributedTitle.length > 0, "attributed title has content")
}
```

Add this entry to the `tests` array after `"menu bar display settings store persists rows"`:

```swift
    ("menu bar attributed title uses stacked title string", testMenuBarAttributedTitleUsesStackedTitleString),
```

- [ ] **Step 2: Run test to verify RED**

Run:

```bash
swift run iMonCoreSelfTests
```

Expected: compile failure because the `iMonApp` module or `MenuBarAttributedTitleFactory` does not exist.

- [ ] **Step 3: Add `iMonApp` target and helper**

Replace `Package.swift` with:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iMon",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "iMonCore", targets: ["iMonCore"]),
        .library(name: "iMonApp", targets: ["iMonApp"]),
        .executable(name: "iMon", targets: ["iMon"]),
        .executable(name: "iMonCoreSelfTests", targets: ["iMonCoreSelfTests"])
    ],
    targets: [
        .target(name: "iMonCore"),
        .target(name: "iMonApp", dependencies: ["iMonCore"]),
        .executableTarget(name: "iMon", dependencies: ["iMonCore", "iMonApp"]),
        .executableTarget(name: "iMonCoreSelfTests", dependencies: ["iMonCore", "iMonApp"])
    ],
    swiftLanguageModes: [.v6]
)
```

Create `Sources/iMonApp/MenuBarAttributedTitle.swift`:

```swift
import AppKit
import Foundation
import iMonCore

public enum MenuBarAttributedTitleFactory {
    public static func attributedTitle(for title: MenuBarStackedTitle) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping
        paragraphStyle.maximumLineHeight = 11
        paragraphStyle.minimumLineHeight = 11

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .semibold),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.labelColor,
            .kern: 0
        ]

        return NSAttributedString(string: title.stringValue, attributes: attributes)
    }
}
```

- [ ] **Step 4: Run test to verify GREEN**

Run:

```bash
swift run iMonCoreSelfTests
```

Expected: all self-tests pass.

- [ ] **Step 5: Commit Task 3**

```bash
git add Package.swift Sources/iMonApp/MenuBarAttributedTitle.swift Sources/iMonCoreSelfTests/main.swift
git commit -m "feat: add appkit menu bar title helper"
```

## Task 4: Menu Bar Controller Configuration Wiring

**Files:**
- Modify: `Sources/iMon/main.swift`
- Modify: `Sources/iMonCoreSelfTests/main.swift`

- [ ] **Step 1: Write failing test for disk row entering stacked title**

Add this test after `testStackedMenuTitleUsesCPUOverMemoryAndUploadOverDownload()`:

```swift
func testStackedMenuTitleCanIncludeDiskWhenConfigured() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592),
        disk: DiskUsage(usedBytes: 50, totalBytes: 100),
        network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
    )
    let settings = MenuBarDisplaySettings(
        showsCPU: true,
        showsMemory: true,
        showsUpload: true,
        showsDownload: true,
        showsDisk: true
    )

    let title = MenuBarTitleFormatter.stackedTitle(for: snapshot, settings: settings)

    try expectEqual(title.topLine, "CPU 25%  ↑ 128K  DSK 50%", "top line with disk")
    try expectEqual(title.bottomLine, "MEM 75%  ↓ 1.5M", "bottom line with disk")
}
```

Add this entry to the `tests` array after `"stacked menu title uses CPU over memory and upload over download"`:

```swift
    ("stacked menu title can include disk when configured", testStackedMenuTitleCanIncludeDiskWhenConfigured),
```

- [ ] **Step 2: Run test to verify RED**

Run:

```bash
swift run iMonCoreSelfTests
```

Expected: this new test fails because disk-column bottom padding leaves trailing spacing or the disk column is not yet included exactly as specified.

- [ ] **Step 3: Add disk column and trim optional one-row columns**

In `Sources/iMonCore/MenuBarDisplay.swift`, add this block after the network column block and before `guard !columns.isEmpty`:

```swift
        let diskColumn = column(
            top: settings.showsDisk ? "DSK \(MetricFormatter.percent(snapshot.disk.percentage))" : "",
            bottom: ""
        )
        if let diskColumn {
            columns.append(diskColumn)
        }
```

Then replace the return at the end of `stackedTitle(for:settings:)` with the following. Keep the existing `trimmingTrailingSpaces()` helper from Task 1; do not use `.trimmingCharacters(in: .whitespaces)` on `bottomLine`, because that removes leading padding needed for column alignment when some rows are hidden.

```swift
        return MenuBarStackedTitle(
            topLine: columns.map(\.top).joined(separator: "  ").trimmingTrailingSpaces(),
            bottomLine: columns.map(\.bottom).joined(separator: "  ").trimmingTrailingSpaces()
        )
```

- [ ] **Step 4: Run test to verify GREEN**

Run:

```bash
swift run iMonCoreSelfTests
```

Expected: all self-tests pass.

- [ ] **Step 5: Wire `MenuBarController` to settings, attributed title, and toggles**

Replace the `import` block in `Sources/iMon/main.swift` with:

```swift
import AppKit
import Foundation
import iMonApp
import iMonCore
```

Inside `MenuBarController`, replace the existing menu item properties with:

```swift
    private let statusItem: NSStatusItem
    private let sampler: SystemSampler
    private let settingsStore: MenuBarDisplaySettingsStore
    private let menu = NSMenu()
    private let cpuToggleItem = NSMenuItem()
    private let memoryToggleItem = NSMenuItem()
    private let uploadToggleItem = NSMenuItem()
    private let downloadToggleItem = NSMenuItem()
    private let diskToggleItem = NSMenuItem()
    private let cpuItem = NSMenuItem()
    private let memoryItem = NSMenuItem()
    private let diskItem = NSMenuItem()
    private let uploadItem = NSMenuItem()
    private let downloadItem = NSMenuItem()
    private var settings: MenuBarDisplaySettings
    private var latestSnapshot: SystemSnapshot?
    private var timer: Timer?
```

Replace the initializer with:

```swift
    init(
        statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
        sampler: SystemSampler = .live(),
        settingsStore: MenuBarDisplaySettingsStore = MenuBarDisplaySettingsStore()
    ) {
        self.statusItem = statusItem
        self.sampler = sampler
        self.settingsStore = settingsStore
        self.settings = settingsStore.load()
        super.init()
        configureMenu()
    }
```

Replace `configureMenu()` with:

```swift
    private func configureMenu() {
        statusItem.button?.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        statusItem.button?.title = "iMon"
        statusItem.menu = menu

        configureToggle(cpuToggleItem, title: "Show CPU in Menu Bar", action: #selector(toggleCPU))
        configureToggle(memoryToggleItem, title: "Show Memory in Menu Bar", action: #selector(toggleMemory))
        configureToggle(uploadToggleItem, title: "Show Upload in Menu Bar", action: #selector(toggleUpload))
        configureToggle(downloadToggleItem, title: "Show Download in Menu Bar", action: #selector(toggleDownload))
        configureToggle(diskToggleItem, title: "Show Disk in Menu Bar", action: #selector(toggleDisk))

        menu.addItem(NSMenuItem(title: "Menu Bar", action: nil, keyEquivalent: ""))
        menu.addItem(cpuToggleItem)
        menu.addItem(memoryToggleItem)
        menu.addItem(uploadToggleItem)
        menu.addItem(downloadToggleItem)
        menu.addItem(diskToggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Details", action: nil, keyEquivalent: ""))
        menu.addItem(cpuItem)
        menu.addItem(memoryItem)
        menu.addItem(diskItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(uploadItem)
        menu.addItem(downloadItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit iMon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        updateToggleStates()
    }

    private func configureToggle(_ item: NSMenuItem, title: String, action: Selector) {
        item.title = title
        item.target = self
        item.action = action
    }
```

Replace `update()` with:

```swift
    private func update() {
        let snapshot = sampler.sample()
        latestSnapshot = snapshot
        renderTitle(for: snapshot)
        updateDetailItems(for: snapshot)
    }

    private func renderTitle(for snapshot: SystemSnapshot) {
        let title = MenuBarTitleFormatter.stackedTitle(for: snapshot, settings: settings)
        statusItem.button?.title = ""
        statusItem.button?.attributedTitle = MenuBarAttributedTitleFactory.attributedTitle(for: title)
    }

    private func updateDetailItems(for snapshot: SystemSnapshot) {
        cpuItem.title = "CPU: \(MetricFormatter.percent(snapshot.cpu.active))"
        memoryItem.title = "Memory: \(MetricFormatter.percent(snapshot.memory.percentage)) (\(MetricFormatter.bytes(snapshot.memory.usedBytes)) / \(MetricFormatter.bytes(snapshot.memory.totalBytes)))"
        diskItem.title = "Disk: \(MetricFormatter.percent(snapshot.disk.percentage)) (\(MetricFormatter.bytes(snapshot.disk.usedBytes)) / \(MetricFormatter.bytes(snapshot.disk.totalBytes)))"
        uploadItem.title = "Upload: \(MetricFormatter.rate(snapshot.network.transmitBytesPerSecond))"
        downloadItem.title = "Download: \(MetricFormatter.rate(snapshot.network.receiveBytesPerSecond))"
    }
```

Add these methods inside `MenuBarController` before `update()`:

```swift
    @objc private func toggleCPU() {
        toggle(.cpu)
    }

    @objc private func toggleMemory() {
        toggle(.memory)
    }

    @objc private func toggleUpload() {
        toggle(.upload)
    }

    @objc private func toggleDownload() {
        toggle(.download)
    }

    @objc private func toggleDisk() {
        toggle(.disk)
    }

    private func toggle(_ metric: MenuBarDisplayMetric) {
        settings.toggle(metric)
        settingsStore.save(settings)
        updateToggleStates()
        if let latestSnapshot {
            renderTitle(for: latestSnapshot)
        }
    }

    private func updateToggleStates() {
        cpuToggleItem.state = settings.showsCPU ? .on : .off
        memoryToggleItem.state = settings.showsMemory ? .on : .off
        uploadToggleItem.state = settings.showsUpload ? .on : .off
        downloadToggleItem.state = settings.showsDownload ? .on : .off
        diskToggleItem.state = settings.showsDisk ? .on : .off
    }
```

- [ ] **Step 6: Run tests and build**

Run:

```bash
swift run iMonCoreSelfTests
swift build
```

Expected: all self-tests pass and build exits 0.

- [ ] **Step 7: Commit Task 4**

```bash
git add Sources/iMon/main.swift Sources/iMonCore/MenuBarDisplay.swift Sources/iMonCoreSelfTests/main.swift
git commit -m "feat: wire compact menu bar controls"
```

## Task 5: Documentation And Final Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write failing documentation check**

Run:

```bash
rg -n "compact stacked|Menu Bar section|Show CPU in Menu Bar" README.md
```

Expected: no matches and exit code 1.

- [ ] **Step 2: Update README usage notes**

In `README.md`, replace the paragraph under `## Run` with:

```markdown
The app appears in the macOS menu bar and uses accessory activation policy, so it does not show a Dock icon. The menu bar title uses compact stacked values by default: CPU appears above memory, and upload appears above download. Open the status menu and use the `Menu Bar` section to choose which values appear in the menu bar.
```

- [ ] **Step 3: Run documentation check to verify GREEN**

Run:

```bash
rg -n "compact stacked|Menu Bar section|upload appears above download" README.md
```

Expected: matches in the `## Run` section.

- [ ] **Step 4: Run full verification**

Run:

```bash
swift run iMonCoreSelfTests
swift build
git status --short
```

Expected: self-tests pass, build exits 0, and `git status --short` shows only `M README.md` before the task commit.

- [ ] **Step 5: Commit Task 5**

```bash
git add README.md
git commit -m "docs: describe compact menu bar controls"
```

## Final Review Requirements

After all tasks:

- Run `swift run iMonCoreSelfTests`.
- Run `swift build`.
- Run `git status --short`.
- Re-read `docs/superpowers/specs/2026-06-28-imon-compact-menubar-design.md` and verify:
  - CPU is above memory.
  - Upload is above download.
  - Default visible rows are CPU, memory, upload, and download.
  - Disk is hidden from the menu bar by default.
  - Each row can be toggled from the menu.
  - `NSStatusItem.view` is not used.
  - The fallback title is `iMon`.
- Request final code review before finishing the branch.
