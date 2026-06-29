import AppKit
import Dispatch
import Foundation
import iMonApp
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

func testCompactRateFormatterOmitsPerSecondForMenuBar() throws {
    try expectEqual(MetricFormatter.compactRate(0), "0B", "zero compact rate")
    try expectEqual(MetricFormatter.compactRate(512), "512B", "byte compact rate")
    try expectEqual(MetricFormatter.compactRate(1_024), "1K", "one kilobyte compact rate")
    try expectEqual(MetricFormatter.compactRate(41 * 1_024), "41K", "kilobyte compact rate has no decimal")
    try expectEqual(MetricFormatter.compactRate(244 * 1_024), "244K", "larger kilobyte compact rate has no decimal")
    try expectEqual(MetricFormatter.compactRate(1_258_291), "1.2M", "megabyte compact rate has one decimal")
    try expectEqual(MetricFormatter.compactRate(1_610_612_736), "1.5G", "gigabyte compact rate")
}

func testCPULoadPressureNormalizesLoadAverageByActiveProcessors() throws {
    let load = CPULoadPressure(oneMinuteLoad: 4.2, activeProcessorCount: 10)

    try expectEqual(load.percentage, 42, "load pressure percentage")
    try expectEqual(load.level, .normal, "load pressure level")
}

func testCPULoadPressureLevelsUseSchedulingPressureThresholds() throws {
    try expectEqual(CPULoadPressure(oneMinuteLoad: 6.9, activeProcessorCount: 10).level, .normal, "normal load")
    try expectEqual(CPULoadPressure(oneMinuteLoad: 7, activeProcessorCount: 10).level, .warning, "warning load")
    try expectEqual(CPULoadPressure(oneMinuteLoad: 10, activeProcessorCount: 10).level, .high, "high load")
    try expectEqual(CPULoadPressure(oneMinuteLoad: 15, activeProcessorCount: 10).level, .critical, "critical load")
    try expectEqual(CPULoadPressure.unknown.level, .unknown, "unknown load")
}

func testCompactLoadPressureFormatterUsesPercentForMenuBar() throws {
    try expectEqual(MetricFormatter.compactLoadPressure(CPULoadPressure(oneMinuteLoad: 4.2, activeProcessorCount: 10)), "42%", "compact load")
    try expectEqual(MetricFormatter.compactLoadPressure(.unknown), "--", "unknown compact load")
}

func testMemoryUsageCarriesPressureLevel() throws {
    let memory = MemoryUsage(
        usedBytes: 6_442_450_944,
        totalBytes: 8_589_934_592,
        pressure: .warning
    )

    try expectEqual(memory.percentage, 75, "memory percentage")
    try expectEqual(memory.pressure, .warning, "memory pressure")
}

func testPressureFormatterUsesEnglishLabels() throws {
    try expectEqual(MetricFormatter.memoryPressure(.normal), "Normal", "normal pressure label")
    try expectEqual(MetricFormatter.memoryPressure(.warning), "Warning", "warning pressure label")
    try expectEqual(MetricFormatter.memoryPressure(.critical), "Critical", "critical pressure label")
    try expectEqual(MetricFormatter.compactMemoryPressure(.normal), " Low", "normal compact pressure")
    try expectEqual(MetricFormatter.compactMemoryPressure(.warning), " Mid", "warning compact pressure")
    try expectEqual(MetricFormatter.compactMemoryPressure(.critical), "High", "critical compact pressure")
}

func testStackedMenuTitleUsesAlignedDefaultMetrics() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        cpuLoad: CPULoadPressure(oneMinuteLoad: 3, activeProcessorCount: 10),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592, pressure: .warning),
        disk: DiskUsage(usedBytes: 50, totalBytes: 100),
        network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
    )

    let title = MenuBarTitleFormatter.stackedTitle(for: snapshot, settings: .defaults)

    try expectEqual(title.topLine, "C  25%  M  75%  ↑  128K", "top line")
    try expectEqual(title.bottomLine, "L  30%  P  Mid  ↓  1.5M", "bottom line")
    try expectEqual(title.stringValue, "C  25%  M  75%  ↑  128K\nL  30%  P  Mid  ↓  1.5M", "stacked title string")
}

func testStackedMenuTitleCanHideCPULoadWhenConfigured() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        cpuLoad: CPULoadPressure(oneMinuteLoad: 3, activeProcessorCount: 10),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592, pressure: .normal),
        disk: DiskUsage(usedBytes: 50, totalBytes: 100),
        network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
    )
    let settings = MenuBarDisplaySettings(
        showsCPU: true,
        showsCPULoad: false,
        showsMemory: true,
        showsMemoryPressure: true,
        showsUpload: true,
        showsDownload: true,
        showsDiskUsed: false,
        showsDiskFree: false
    )

    let title = MenuBarTitleFormatter.stackedTitle(for: snapshot, settings: settings)

    try expectEqual(title.topLine, "C  25%  M  75%  ↑  128K", "top line")
    try expectEqual(title.bottomLine, "        P  Low  ↓  1.5M", "bottom line")
    try expect(!title.bottomLine.hasPrefix("L "), "CPU load is hidden")
}

func testStackedMenuTitleCanIncludeDiskUsedAndFreeWhenConfigured() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592),
        disk: DiskUsage(usedBytes: 384 * 1_073_741_824, totalBytes: 512 * 1_073_741_824),
        network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
    )
    let settings = MenuBarDisplaySettings(
        showsCPU: true,
        showsCPULoad: true,
        showsMemory: true,
        showsMemoryPressure: true,
        showsUpload: true,
        showsDownload: true,
        showsDiskUsed: true,
        showsDiskFree: true
    )

    let title = MenuBarTitleFormatter.stackedTitle(for: snapshot, settings: settings)

    try expectEqual(title.topLine, "C  25%  M  75%  ↑  128K  D   75%", "top line with disk")
    try expectEqual(title.bottomLine, "L   --  P  Low  ↓  1.5M  F  128G", "bottom line with disk")
}

func testStackedMenuTitlePreservesLeadingPaddingForPartialVisibility() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592),
        disk: DiskUsage(usedBytes: 50, totalBytes: 100),
        network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
    )
    let settings = MenuBarDisplaySettings(
        showsCPU: true,
        showsCPULoad: false,
        showsMemory: false,
        showsMemoryPressure: false,
        showsUpload: true,
        showsDownload: true,
        showsDiskUsed: false,
        showsDiskFree: false
    )

    let title = MenuBarTitleFormatter.stackedTitle(for: snapshot, settings: settings)

    try expectEqual(title.topLine, "C  25%  ↑  128K", "top line")
    try expectEqual(title.bottomLine, "        ↓  1.5M", "bottom line")
    try expectEqual(title.stringValue, "C  25%  ↑  128K\n        ↓  1.5M", "stacked title string")
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
        showsCPULoad: false,
        showsMemory: false,
        showsMemoryPressure: false,
        showsUpload: false,
        showsDownload: false,
        showsDiskUsed: false,
        showsDiskFree: false
    )

    let title = MenuBarTitleFormatter.stackedTitle(for: snapshot, settings: settings)

    try expectEqual(title.topLine, "iMon", "fallback top line")
    try expectEqual(title.bottomLine, "", "fallback bottom line")
    try expectEqual(title.stringValue, "iMon", "fallback title string")
}

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
    try expect(settings.isVisible(.cpuLoad), "CPU load visible by default")
    try expect(settings.isVisible(.memory), "memory visible by default")
    try expect(settings.isVisible(.memoryPressure), "memory pressure visible by default")
    try expect(settings.isVisible(.upload), "upload visible by default")
    try expect(settings.isVisible(.download), "download visible by default")
    try expect(!settings.isVisible(.diskUsed), "disk used hidden by default")
    try expect(!settings.isVisible(.diskFree), "disk free hidden by default")
}

func testMenuBarDisplaySettingsStoreUsesDefaultsWhenKeysAreMissing() throws {
    let defaults = makeIsolatedDefaults(name: "display-store-missing-keys")
    let store = MenuBarDisplaySettingsStore(defaults: defaults, keyPrefix: "testMenuBar")

    let loaded = store.load()

    try expectEqual(loaded, .defaults, "missing keys load default settings")
}

func testMenuBarDisplaySettingsToggleChangesOnlySelectedMetric() throws {
    var settings = MenuBarDisplaySettings.defaults

    settings.toggle(.upload)

    try expect(settings.isVisible(.cpu), "CPU remains visible")
    try expect(settings.isVisible(.cpuLoad), "CPU load remains visible")
    try expect(settings.isVisible(.memory), "memory remains visible")
    try expect(settings.isVisible(.memoryPressure), "memory pressure remains visible")
    try expect(!settings.isVisible(.upload), "upload toggled off")
    try expect(settings.isVisible(.download), "download remains visible")
    try expect(!settings.isVisible(.diskUsed), "disk used remains hidden")
    try expect(!settings.isVisible(.diskFree), "disk free remains hidden")
}

func testMenuBarDisplaySettingsStorePersistsRows() throws {
    let defaults = makeIsolatedDefaults(name: "display-store")
    let store = MenuBarDisplaySettingsStore(defaults: defaults, keyPrefix: "testMenuBar")
    var settings = MenuBarDisplaySettings.defaults
    settings.toggle(.cpu)
    settings.toggle(.cpuLoad)
    settings.toggle(.memoryPressure)
    settings.toggle(.diskUsed)
    settings.toggle(.diskFree)

    store.save(settings)
    let loaded = store.load()

    try expectEqual(loaded, settings, "loaded settings")
}

func testMenuBarAttributedTitleUsesStackedTitleString() throws {
    let stackedTitle = MenuBarStackedTitle(
        topLine: "M  75%  ↑  128K",
        bottomLine: "P  Mid  ↓  1.5M"
    )

    let attributedTitle = MenuBarAttributedTitleFactory.attributedTitle(for: stackedTitle)

    try expectEqual(attributedTitle.string, "M  75%  ↑  128K\nP  Mid  ↓  1.5M", "attributed title string")
    try expect(attributedTitle.length > 0, "attributed title has content")
}

func testMenuBarAttributedTitleColorsMemoryPressureValue() throws {
    let stackedTitle = MenuBarStackedTitle(
        topLine: "M  75%  ↑  128K",
        bottomLine: "P High  ↓  1.5M"
    )

    let attributedTitle = MenuBarAttributedTitleFactory.attributedTitle(for: stackedTitle, memoryPressure: .critical)
    let pressureRange = (attributedTitle.string as NSString).range(of: "High")
    try expect(pressureRange.location != NSNotFound, "critical pressure label is present")
    let color = attributedTitle.attribute(.foregroundColor, at: pressureRange.location, effectiveRange: nil) as? NSColor

    try expectEqual(color, NSColor.systemRed, "critical pressure color")
}

func testMenuBarAttributedTitleColorsCPULoadValue() throws {
    let stackedTitle = MenuBarStackedTitle(
        topLine: "C  25%  M   75%  ↑  128K",
        bottomLine: "L 120%  P   Low  ↓  1.5M"
    )

    let load = CPULoadPressure(oneMinuteLoad: 12, activeProcessorCount: 10)
    let attributedTitle = MenuBarAttributedTitleFactory.attributedTitle(for: stackedTitle, cpuLoad: load, memoryPressure: .normal)
    let loadRange = (attributedTitle.string as NSString).range(of: "120%")
    try expect(loadRange.location != NSNotFound, "load value is present")
    let color = attributedTitle.attribute(.foregroundColor, at: loadRange.location, effectiveRange: nil) as? NSColor

    try expectEqual(color, NSColor.systemOrange, "high load color")
}

func testMenuBarMetricsViewModelUsesUnpaddedValuesAndDynamicValueColors() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        cpuLoad: CPULoadPressure(oneMinuteLoad: 3, activeProcessorCount: 10),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592, pressure: .normal),
        disk: DiskUsage(usedBytes: 50, totalBytes: 100),
        network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
    )

    let model = MenuBarMetricsViewModelFactory.viewModel(for: snapshot, settings: .defaults)

    try expectEqual(model.columns.count, 3, "default column count")
    try expectEqual(model.columns[0].top.label, "C", "CPU label")
    try expectEqual(model.columns[0].top.value, "25%", "CPU value")
    try expectEqual(model.columns[0].bottom.label, "L", "load label")
    try expectEqual(model.columns[0].bottom.value, "30%", "load value")
    try expectEqual(model.columns[0].bottom.valueColor, NSColor.systemGreen, "load value color")
    try expectEqual(model.columns[1].top.label, "M", "memory label")
    try expectEqual(model.columns[1].bottom.label, "P", "pressure label")
    try expectEqual(model.columns[1].bottom.valueColor, NSColor.systemGreen, "pressure value color")
    try expectEqual(model.columns[2].top.label, "↑", "upload arrow label")
    try expectEqual(model.columns[2].top.value, "128K", "unpadded upload value")
    try expectEqual(model.columns[2].top.reservedValue, "99.9M", "upload value reserves stable but compact width")
    try expectEqual(model.columns[2].bottom.label, "↓", "download arrow label")
    try expectEqual(model.columns[2].bottom.value, "1.5M", "unpadded download value")
    try expectEqual(model.columns[2].bottom.reservedValue, "99.9M", "download value reserves stable but compact width")
}

@MainActor
func testMenuBarMetricsViewLeftAlignsLabelsAndRightAlignsValuesForEveryMetric() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 4, system: 5, idle: 91),
        cpuLoad: CPULoadPressure(oneMinuteLoad: 3, activeProcessorCount: 10),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592, pressure: .normal),
        disk: DiskUsage(usedBytes: 384 * 1_073_741_824, totalBytes: 512 * 1_073_741_824),
        network: NetworkRate(receiveBytesPerSecond: 9 * 1_024, transmitBytesPerSecond: 35 * 1_024)
    )
    let settings = MenuBarDisplaySettings(
        showsCPU: true,
        showsCPULoad: true,
        showsMemory: true,
        showsMemoryPressure: true,
        showsUpload: true,
        showsDownload: true,
        showsDiskUsed: true,
        showsDiskFree: true
    )
    let model = MenuBarMetricsViewModelFactory.viewModel(for: snapshot, settings: settings)
    let rows = model.columns.flatMap { [$0.top, $0.bottom] }

    try expectEqual(rows.map(\.label), ["C", "L", "M", "P", "↑", "↓", "D", "F"], "metric rows under test")

    for row in rows {
        let layout = MenuBarMetricsView.rowLayout(
            for: row,
            in: NSRect(x: 0, y: 0, width: 100, height: MenuBarMetricsView.lineHeight)
        )

        try expectEqual(layout.labelRect.minX, 0, "\(row.label) label is left-aligned")
        try expectEqual(layout.valueRect.maxX, 100, "\(row.label) value is right-aligned")
    }
}

func testMenuBarMetricsViewModelCanShowDiskUsedAndFreeSeparately() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592),
        disk: DiskUsage(usedBytes: 384 * 1_073_741_824, totalBytes: 512 * 1_073_741_824),
        network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
    )
    let settings = MenuBarDisplaySettings(
        showsCPU: false,
        showsCPULoad: false,
        showsMemory: false,
        showsMemoryPressure: false,
        showsUpload: false,
        showsDownload: false,
        showsDiskUsed: true,
        showsDiskFree: true
    )

    let model = MenuBarMetricsViewModelFactory.viewModel(for: snapshot, settings: settings)

    try expectEqual(model.columns.count, 1, "disk column count")
    try expectEqual(model.columns[0].top.label, "D", "disk used label")
    try expectEqual(model.columns[0].top.value, "75%", "disk used value")
    try expectEqual(model.columns[0].bottom.label, "F", "disk free label")
    try expectEqual(model.columns[0].bottom.value, "128G", "disk free value")
}

@MainActor
func testMenuBarMetricsViewKeepsNetworkWidthStableAcrossKAndMValues() throws {
    let kiloSnapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592),
        disk: DiskUsage(usedBytes: 50, totalBytes: 100),
        network: NetworkRate(receiveBytesPerSecond: 41 * 1_024, transmitBytesPerSecond: 244 * 1_024)
    )
    let megaSnapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592),
        disk: DiskUsage(usedBytes: 50, totalBytes: 100),
        network: NetworkRate(receiveBytesPerSecond: 1_258_291, transmitBytesPerSecond: 1_258_291)
    )

    let kiloModel = MenuBarMetricsViewModelFactory.viewModel(for: kiloSnapshot, settings: .defaults)
    let megaModel = MenuBarMetricsViewModelFactory.viewModel(for: megaSnapshot, settings: .defaults)

    try expectEqual(
        MenuBarMetricsView.statusItemLength(for: kiloModel),
        MenuBarMetricsView.statusItemLength(for: megaModel),
        "status item length stays fixed for K and M network values"
    )
}

@MainActor
func testMenuBarMetricsViewUsesLessWidthThanSpacePaddedTitle() throws {
    let snapshot = SystemSnapshot(
        timestamp: Date(timeIntervalSince1970: 10),
        cpu: CPUUsage(user: 10, system: 15, idle: 75),
        cpuLoad: CPULoadPressure(oneMinuteLoad: 3, activeProcessorCount: 10),
        memory: MemoryUsage(usedBytes: 6_442_450_944, totalBytes: 8_589_934_592, pressure: .normal),
        disk: DiskUsage(usedBytes: 50, totalBytes: 100),
        network: NetworkRate(receiveBytesPerSecond: 1_572_864, transmitBytesPerSecond: 131_072)
    )

    let model = MenuBarMetricsViewModelFactory.viewModel(for: snapshot, settings: .defaults)
    let compactWidth = MenuBarMetricsView.statusItemLength(for: model)
    let stackedTitle = MenuBarTitleFormatter.stackedTitle(for: snapshot, settings: .defaults)
    let paddedWidth = MenuBarAttributedTitleFactory.statusItemLength(
        for: MenuBarAttributedTitleFactory.attributedTitle(for: stackedTitle)
    )

    try expect(compactWidth + 20 < paddedWidth, "custom view width is meaningfully smaller than padded text title")
}

@MainActor
func testMenuBarMetricsViewAllowsStatusButtonToReceiveClicks() throws {
    let model = MenuBarMetricsViewModel(columns: [
        MenuBarMetricsColumn(
            top: MenuBarMetricValue(label: "C", value: "25%"),
            bottom: MenuBarMetricValue(label: "L", value: "30%")
        )
    ])
    let view = MenuBarMetricsView(model: model)
    view.frame = NSRect(x: 0, y: 0, width: 80, height: 22)

    try expect(view.hitTest(NSPoint(x: 10, y: 10)) == nil, "metrics view lets clicks pass through to the status button")
}

func testMenuBarAttributedTitleAppliesOpticalCenteringAttributes() throws {
    let stackedTitle = MenuBarStackedTitle(
        topLine: "M  75%  ↑  128K",
        bottomLine: "P  Mid  ↓  1.5M"
    )

    let attributedTitle = MenuBarAttributedTitleFactory.attributedTitle(for: stackedTitle)
    let baselineOffset = attributedTitle.attribute(.baselineOffset, at: 0, effectiveRange: nil) as? CGFloat
    let paragraphStyle = attributedTitle.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    let paddedLength = MenuBarAttributedTitleFactory.statusItemLength(for: attributedTitle)

    try expectEqual(baselineOffset, MenuBarAttributedTitleFactory.baselineOffset, "baseline offset")
    try expect((baselineOffset ?? 0) < 0, "negative baseline offset moves the two-line title down")
    try expectEqual(paragraphStyle?.alignment, .center, "paragraph alignment")
    try expectEqual(paragraphStyle?.minimumLineHeight, MenuBarAttributedTitleFactory.lineHeight, "minimum line height")
    try expectEqual(paragraphStyle?.maximumLineHeight, MenuBarAttributedTitleFactory.lineHeight, "maximum line height")
    try expect(
        paddedLength >= ceil(attributedTitle.size().width) + MenuBarAttributedTitleFactory.horizontalPadding * 2,
        "status item length includes horizontal padding"
    )
}

func testMenuBarSectionItemIsDisabled() throws {
    let item = MenuBarMenuItemFactory.sectionTitle("Menu Bar")

    try expectEqual(item.title, "Menu Bar", "section title")
    try expect(!item.isEnabled, "section item is disabled")
    try expect(item.action == nil, "section item has no action")
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
        "M  75%  ↑  128K\nP  Low  ↓  1.5M",
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

private struct FixedMemoryPressureProvider: MemoryPressureSampleProvider {
    let level: MemoryPressureLevel

    func sample() -> MemoryPressureLevel {
        level
    }
}

private struct FixedCPULoadProvider: CPULoadSampleProvider {
    let load: CPULoadPressure

    func sample() -> CPULoadPressure {
        load
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

func testSamplerIncludesCPULoadPressure() throws {
    let sampler = SystemSampler(
        cpuProvider: FakeCPUProvider([CPUTicks(user: 10, system: 5, idle: 85)]),
        memoryProvider: FakeMemoryProvider(),
        diskProvider: FakeDiskProvider(),
        networkProvider: FakeNetworkProvider([NetworkCounters(receivedBytes: 1_000, transmittedBytes: 2_000)]),
        cpuLoadProvider: FixedCPULoadProvider(load: CPULoadPressure(oneMinuteLoad: 4.2, activeProcessorCount: 10))
    )

    let snapshot = sampler.sample(now: Date(timeIntervalSince1970: 1))

    try expectEqual(snapshot.cpuLoad.percentage, 42, "sample CPU load pressure")
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

func testDefaultSamplerCanBeConstructed() throws {
    let sampler = SystemSampler.live()
    let snapshot = sampler.sample(now: Date(timeIntervalSince1970: 1))

    try expect(snapshot.cpu.active >= 0, "live CPU active is non-negative")
    try expect(snapshot.memory.totalBytes >= 0, "live memory total is non-negative")
    try expect(snapshot.disk.totalBytes >= 0, "live disk total is non-negative")
    try expect(snapshot.cpuLoad.percentage >= 0, "live CPU load pressure is non-negative")
}

func testMemoryPressureProviderMapsDispatchEvents() throws {
    try expectEqual(MacOSMemoryPressureProvider.level(for: .normal), .normal, "normal pressure event")
    try expectEqual(MacOSMemoryPressureProvider.level(for: .warning), .warning, "warning pressure event")
    try expectEqual(MacOSMemoryPressureProvider.level(for: .critical), .critical, "critical pressure event")
    try expectEqual(
        MacOSMemoryPressureProvider.level(for: [.warning, .critical]),
        .critical,
        "critical pressure wins combined events"
    )
}

func testMacOSMemoryProviderIncludesPressureSample() throws {
    let memory = try MacOSMemoryProvider(
        pressureProvider: FixedMemoryPressureProvider(level: .critical)
    ).sample()

    try expectEqual(memory.pressure, .critical, "macOS memory provider pressure")
}

func testLiveProvidersReturnPlausibleSamples() throws {
    let cpu = try MacOSCPUProvider().sample()
    let cpuLoad = MacOSCPULoadProvider().sample()
    let memory = try MacOSMemoryProvider().sample()
    let disk = try MacOSDiskProvider().sample()
    let network = try MacOSNetworkProvider().sample()

    try expect(cpu.user + cpu.system + cpu.idle > 0, "live CPU ticks are positive")
    try expect(cpuLoad.percentage >= 0, "live CPU load is non-negative")
    try expect(memory.totalBytes > 0, "live memory total is positive")
    try expect(disk.totalBytes > 0, "live disk total is positive")
    try expect(disk.usedBytes <= disk.totalBytes, "live disk used does not exceed total")
    try expect(network.receivedBytes >= 0, "live network received bytes is non-negative")
    try expect(network.transmittedBytes >= 0, "live network transmitted bytes is non-negative")
}

let tests: [(String, () throws -> Void)] = [
    ("percentage clamps into display range", testPercentageClampsIntoDisplayRange),
    ("byte formatter uses compact binary units", testByteFormatterUsesCompactBinaryUnits),
    ("compact rate formatter omits per-second for menu bar", testCompactRateFormatterOmitsPerSecondForMenuBar),
    ("CPU load pressure normalizes load average by active processors", testCPULoadPressureNormalizesLoadAverageByActiveProcessors),
    ("CPU load pressure levels use scheduling pressure thresholds", testCPULoadPressureLevelsUseSchedulingPressureThresholds),
    ("compact load pressure formatter uses percent for menu bar", testCompactLoadPressureFormatterUsesPercentForMenuBar),
    ("memory usage carries pressure level", testMemoryUsageCarriesPressureLevel),
    ("pressure formatter uses English labels", testPressureFormatterUsesEnglishLabels),
    ("stacked menu title uses aligned default metrics", testStackedMenuTitleUsesAlignedDefaultMetrics),
    ("stacked menu title can hide CPU load when configured", testStackedMenuTitleCanHideCPULoadWhenConfigured),
    ("stacked menu title can include disk used and free when configured", testStackedMenuTitleCanIncludeDiskUsedAndFreeWhenConfigured),
    ("stacked menu title preserves leading padding for partial visibility", testStackedMenuTitlePreservesLeadingPaddingForPartialVisibility),
    ("stacked menu title falls back when every row is hidden", testStackedMenuTitleFallsBackWhenEveryRowIsHidden),
    ("menu bar display settings default rows", testMenuBarDisplaySettingsDefaultRows),
    ("menu bar display settings store uses defaults when keys are missing", testMenuBarDisplaySettingsStoreUsesDefaultsWhenKeysAreMissing),
    ("menu bar display settings toggle changes only selected metric", testMenuBarDisplaySettingsToggleChangesOnlySelectedMetric),
    ("menu bar display settings store persists rows", testMenuBarDisplaySettingsStorePersistsRows),
    ("menu bar attributed title uses stacked title string", testMenuBarAttributedTitleUsesStackedTitleString),
    ("menu bar attributed title colors memory pressure value", testMenuBarAttributedTitleColorsMemoryPressureValue),
    ("menu bar attributed title colors CPU load value", testMenuBarAttributedTitleColorsCPULoadValue),
    ("menu bar metrics view model uses unpadded values and dynamic value colors", testMenuBarMetricsViewModelUsesUnpaddedValuesAndDynamicValueColors),
    ("menu bar metrics view left-aligns labels and right-aligns values for every metric", { try MainActor.assumeIsolated { try testMenuBarMetricsViewLeftAlignsLabelsAndRightAlignsValuesForEveryMetric() } }),
    ("menu bar metrics view model can show disk used and free separately", testMenuBarMetricsViewModelCanShowDiskUsedAndFreeSeparately),
    ("menu bar metrics view keeps network width stable across K and M values", { try MainActor.assumeIsolated { try testMenuBarMetricsViewKeepsNetworkWidthStableAcrossKAndMValues() } }),
    ("menu bar metrics view uses less width than space padded title", { try MainActor.assumeIsolated { try testMenuBarMetricsViewUsesLessWidthThanSpacePaddedTitle() } }),
    ("menu bar metrics view allows status button to receive clicks", { try MainActor.assumeIsolated { try testMenuBarMetricsViewAllowsStatusButtonToReceiveClicks() } }),
    ("menu bar attributed title applies optical centering attributes", testMenuBarAttributedTitleAppliesOpticalCenteringAttributes),
    ("menu bar section item is disabled", testMenuBarSectionItemIsDisabled),
    ("menu title shows core metrics", testMenuTitleShowsCoreMetrics),
    ("first sample uses zero delta metrics", testFirstSampleUsesZeroDeltaBasedMetrics),
    ("sampler includes CPU load pressure", testSamplerIncludesCPULoadPressure),
    ("second sample computes CPU and network deltas", testSecondSampleComputesCPUAndNetworkDeltas),
    ("counter reset returns zero rate", testCounterResetReturnsZeroRateForThatInterval),
    ("zero CPU delta returns idle fallback", testZeroCPUDeltaReturnsIdleFallback),
    ("non-positive elapsed time returns zero network rate", testNonPositiveElapsedTimeReturnsZeroNetworkRate),
    ("provider failure resets delta baselines", testProviderFailureResetsDeltaBaselines),
    ("default sampler can be constructed", testDefaultSamplerCanBeConstructed),
    ("memory pressure provider maps dispatch events", testMemoryPressureProviderMapsDispatchEvents),
    ("macOS memory provider includes pressure sample", testMacOSMemoryProviderIncludesPressureSample),
    ("live providers return plausible samples", testLiveProvidersReturnPlausibleSamples)
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
