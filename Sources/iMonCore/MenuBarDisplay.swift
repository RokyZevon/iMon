import Foundation

public enum MenuBarDisplayMetric: String, CaseIterable, Equatable, Sendable {
    case cpu
    case memory
    case upload
    case download
    case disk
}

public struct MenuBarDisplaySettings: Equatable, Sendable {
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
