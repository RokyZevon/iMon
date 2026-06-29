import Foundation

public enum MenuBarDisplayMetric: String, CaseIterable, Equatable, Sendable {
    case cpu
    case memory
    case memoryPressure
    case upload
    case download
    case disk
}

public struct MenuBarDisplaySettings: Equatable, Sendable {
    public var showsCPU: Bool
    public var showsMemory: Bool
    public var showsMemoryPressure: Bool
    public var showsUpload: Bool
    public var showsDownload: Bool
    public var showsDisk: Bool

    public init(
        showsCPU: Bool,
        showsMemory: Bool,
        showsMemoryPressure: Bool,
        showsUpload: Bool,
        showsDownload: Bool,
        showsDisk: Bool
    ) {
        self.showsCPU = showsCPU
        self.showsMemory = showsMemory
        self.showsMemoryPressure = showsMemoryPressure
        self.showsUpload = showsUpload
        self.showsDownload = showsDownload
        self.showsDisk = showsDisk
    }

    public static let defaults = MenuBarDisplaySettings(
        showsCPU: false,
        showsMemory: true,
        showsMemoryPressure: true,
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
        case .memoryPressure:
            return showsMemoryPressure
        case .upload:
            return showsUpload
        case .download:
            return showsDownload
        case .disk:
            return showsDisk
        }
    }

    public mutating func toggle(_ metric: MenuBarDisplayMetric) {
        switch metric {
        case .cpu:
            showsCPU.toggle()
        case .memory:
            showsMemory.toggle()
        case .memoryPressure:
            showsMemoryPressure.toggle()
        case .upload:
            showsUpload.toggle()
        case .download:
            showsDownload.toggle()
        case .disk:
            showsDisk.toggle()
        }
    }
}

public struct MenuBarStackedTitle: Equatable, Sendable {
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

        let cpuColumn = column(
            top: settings.showsCPU ? "CPU \(MetricFormatter.percent(snapshot.cpu.active))" : "",
            bottom: ""
        )
        if let cpuColumn {
            columns.append(cpuColumn)
        }

        let memoryColumn = column(
            top: settings.showsMemory ? metricValue(label: "MEM USE", value: MetricFormatter.percent(snapshot.memory.percentage), width: 4) : "",
            bottom: settings.showsMemoryPressure ? metricValue(label: "MEM PRES", value: MetricFormatter.compactMemoryPressure(snapshot.memory.pressure), width: 4) : ""
        )
        if let memoryColumn {
            columns.append(memoryColumn)
        }

        let networkColumn = column(
            top: settings.showsUpload ? "↑ \(MetricFormatter.compactRate(snapshot.network.transmitBytesPerSecond))" : "",
            bottom: settings.showsDownload ? "↓ \(MetricFormatter.compactRate(snapshot.network.receiveBytesPerSecond))" : ""
        )
        if let networkColumn {
            columns.append(networkColumn)
        }

        let diskColumn = column(
            top: settings.showsDisk ? "DSK \(MetricFormatter.percent(snapshot.disk.percentage))" : "",
            bottom: ""
        )
        if let diskColumn {
            columns.append(diskColumn)
        }

        guard !columns.isEmpty else {
            return MenuBarStackedTitle(topLine: "iMon", bottomLine: "")
        }

        return MenuBarStackedTitle(
            topLine: columns.map(\.top).joined(separator: "  ").trimmingTrailingSpaces(),
            bottomLine: columns.map(\.bottom).joined(separator: "  ").trimmingTrailingSpaces()
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

    private static func metricValue(label: String, value: String, width: Int) -> String {
        "\(label.padding(toLength: 8, withPad: " ", startingAt: 0)) \(value.leftPadded(to: width))"
    }
}

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
            showsMemoryPressure: bool(for: .memoryPressure, defaultValue: MenuBarDisplaySettings.defaults.showsMemoryPressure),
            showsUpload: bool(for: .upload, defaultValue: MenuBarDisplaySettings.defaults.showsUpload),
            showsDownload: bool(for: .download, defaultValue: MenuBarDisplaySettings.defaults.showsDownload),
            showsDisk: bool(for: .disk, defaultValue: MenuBarDisplaySettings.defaults.showsDisk)
        )
    }

    public func save(_ settings: MenuBarDisplaySettings) {
        defaults.set(settings.showsCPU, forKey: key(for: .cpu))
        defaults.set(settings.showsMemory, forKey: key(for: .memory))
        defaults.set(settings.showsMemoryPressure, forKey: key(for: .memoryPressure))
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

private extension String {
    func leftPadded(to width: Int) -> String {
        let padding = max(0, width - count)
        return String(repeating: " ", count: padding) + self
    }

    func trimmingTrailingSpaces() -> String {
        var result = self
        while result.last?.isWhitespace == true {
            result.removeLast()
        }
        return result
    }
}
