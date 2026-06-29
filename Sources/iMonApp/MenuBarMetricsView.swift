import AppKit
import Foundation
import iMonCore

public struct MenuBarMetricRowLayout: Equatable {
    public let labelRect: NSRect
    public let valueRect: NSRect

    public init(labelRect: NSRect, valueRect: NSRect) {
        self.labelRect = labelRect
        self.valueRect = valueRect
    }
}

public struct MenuBarMetricValue: Equatable {
    public let label: String
    public let value: String
    public let valueColor: NSColor?
    public let reservedValue: String?

    public init(
        label: String,
        value: String,
        valueColor: NSColor? = nil,
        reservedValue: String? = nil
    ) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.reservedValue = reservedValue
    }
}

public struct MenuBarMetricsColumn: Equatable {
    public let top: MenuBarMetricValue
    public let bottom: MenuBarMetricValue

    public init(top: MenuBarMetricValue, bottom: MenuBarMetricValue) {
        self.top = top
        self.bottom = bottom
    }
}

public struct MenuBarMetricsViewModel: Equatable {
    public let columns: [MenuBarMetricsColumn]

    public init(columns: [MenuBarMetricsColumn]) {
        self.columns = columns
    }
}

public enum MenuBarMetricsViewModelFactory {
    public static func viewModel(
        for snapshot: SystemSnapshot,
        settings: MenuBarDisplaySettings
    ) -> MenuBarMetricsViewModel {
        var columns: [MenuBarMetricsColumn] = []

        if settings.showsCPU || settings.showsCPULoad {
            columns.append(
                MenuBarMetricsColumn(
                    top: settings.showsCPU
                        ? MenuBarMetricValue(label: "C", value: MetricFormatter.percent(snapshot.cpu.active))
                        : MenuBarMetricValue(label: "", value: ""),
                    bottom: settings.showsCPULoad
                        ? MenuBarMetricValue(
                            label: "L",
                            value: MetricFormatter.compactLoadPressure(snapshot.cpuLoad),
                            valueColor: loadColor(for: snapshot.cpuLoad.level)
                        )
                        : MenuBarMetricValue(label: "", value: "")
                )
            )
        }

        if settings.showsMemory || settings.showsMemoryPressure {
            columns.append(
                MenuBarMetricsColumn(
                    top: settings.showsMemory
                        ? MenuBarMetricValue(label: "M", value: MetricFormatter.percent(snapshot.memory.percentage))
                        : MenuBarMetricValue(label: "", value: ""),
                    bottom: settings.showsMemoryPressure
                        ? MenuBarMetricValue(
                            label: "P",
                            value: MetricFormatter.compactMemoryPressure(snapshot.memory.pressure).trimmingCharacters(in: .whitespaces),
                            valueColor: pressureColor(for: snapshot.memory.pressure)
                        )
                        : MenuBarMetricValue(label: "", value: "")
                )
            )
        }

        if settings.showsUpload || settings.showsDownload {
            columns.append(
                MenuBarMetricsColumn(
                    top: settings.showsUpload
                        ? MenuBarMetricValue(
                            label: "↑",
                            value: MetricFormatter.compactRate(snapshot.network.transmitBytesPerSecond),
                            reservedValue: "99.9M"
                        )
                        : MenuBarMetricValue(label: "", value: ""),
                    bottom: settings.showsDownload
                        ? MenuBarMetricValue(
                            label: "↓",
                            value: MetricFormatter.compactRate(snapshot.network.receiveBytesPerSecond),
                            reservedValue: "99.9M"
                        )
                        : MenuBarMetricValue(label: "", value: "")
                )
            )
        }

        if settings.showsDiskUsed || settings.showsDiskFree {
            columns.append(
                MenuBarMetricsColumn(
                    top: settings.showsDiskUsed
                        ? MenuBarMetricValue(label: "D", value: MetricFormatter.percent(snapshot.disk.percentage))
                        : MenuBarMetricValue(label: "", value: ""),
                    bottom: settings.showsDiskFree
                        ? MenuBarMetricValue(label: "F", value: MetricFormatter.compactStorage(snapshot.disk.freeBytes))
                        : MenuBarMetricValue(label: "", value: "")
                )
            )
        }

        if columns.isEmpty {
            columns.append(
                MenuBarMetricsColumn(
                    top: MenuBarMetricValue(label: "iMon", value: ""),
                    bottom: MenuBarMetricValue(label: "", value: "")
                )
            )
        }

        return MenuBarMetricsViewModel(columns: columns)
    }

    private static func loadColor(for level: CPULoadPressureLevel) -> NSColor {
        switch level {
        case .normal:
            return .systemGreen
        case .warning:
            return .systemYellow
        case .high:
            return .systemOrange
        case .critical:
            return .systemRed
        case .unknown:
            return .secondaryLabelColor
        }
    }

    private static func pressureColor(for pressure: MemoryPressureLevel) -> NSColor {
        switch pressure {
        case .normal:
            return .systemGreen
        case .warning:
            return .systemYellow
        case .critical:
            return .systemRed
        case .unknown:
            return .secondaryLabelColor
        }
    }
}

public final class MenuBarMetricsView: NSView {
    public static let lineHeight: CGFloat = 11
    public static let horizontalPadding: CGFloat = 4
    public static let interColumnSpacing: CGFloat = 6
    public static let labelValueSpacing: CGFloat = 3

    private static let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .semibold)
    private var model: MenuBarMetricsViewModel

    public init(model: MenuBarMetricsViewModel) {
        self.model = model
        super.init(frame: .zero)
        wantsLayer = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(model: MenuBarMetricsViewModel) {
        self.model = model
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    public override var intrinsicContentSize: NSSize {
        Self.size(for: model)
    }

    public static func statusItemLength(for model: MenuBarMetricsViewModel) -> CGFloat {
        ceil(size(for: model).width)
    }

    public static func size(for model: MenuBarMetricsViewModel) -> NSSize {
        NSSize(
            width: horizontalPadding * 2 + columnsWidth(for: model),
            height: lineHeight * 2
        )
    }

    public static func rowLayout(for metric: MenuBarMetricValue, in rect: NSRect) -> MenuBarMetricRowLayout {
        let labelSize = textSize(metric.label)
        let valueSize = textSize(metric.value)

        return MenuBarMetricRowLayout(
            labelRect: NSRect(x: rect.minX, y: rect.minY, width: labelSize.width, height: rect.height),
            valueRect: NSRect(x: rect.maxX - valueSize.width, y: rect.minY, width: valueSize.width, height: rect.height)
        )
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        var x = Self.horizontalPadding
        let topBaselineY = max(0, bounds.height - Self.lineHeight)
        let bottomBaselineY: CGFloat = 0

        for column in model.columns {
            let width = Self.columnWidth(column)
            draw(column.top, in: NSRect(x: x, y: topBaselineY, width: width, height: Self.lineHeight))
            draw(column.bottom, in: NSRect(x: x, y: bottomBaselineY, width: width, height: Self.lineHeight))
            x += width + Self.interColumnSpacing
        }
    }

    private func draw(_ metric: MenuBarMetricValue, in rect: NSRect) {
        guard !metric.label.isEmpty || !metric.value.isEmpty else {
            return
        }

        let layout = Self.rowLayout(for: metric, in: rect)

        drawText(
            metric.label,
            color: .labelColor,
            in: layout.labelRect
        )
        drawText(
            metric.value,
            color: metric.valueColor ?? .labelColor,
            in: layout.valueRect
        )
    }

    private func drawText(_ text: String, color: NSColor, in rect: NSRect) {
        guard !text.isEmpty else {
            return
        }

        NSAttributedString(string: text, attributes: [
            .font: Self.font,
            .foregroundColor: color,
            .kern: 0
        ]).draw(in: rect)
    }

    private static func columnsWidth(for model: MenuBarMetricsViewModel) -> CGFloat {
        guard !model.columns.isEmpty else {
            return 0
        }

        let columns = model.columns.map(columnWidth)
        return columns.reduce(0, +) + interColumnSpacing * CGFloat(max(0, columns.count - 1))
    }

    private static func columnWidth(_ column: MenuBarMetricsColumn) -> CGFloat {
        max(rowWidth(column.top), rowWidth(column.bottom))
    }

    private static func rowWidth(_ row: MenuBarMetricValue) -> CGFloat {
        let labelWidth = textSize(row.label).width
        let valueWidth = max(textSize(row.value).width, textSize(row.reservedValue ?? "").width)

        if row.label.isEmpty || row.value.isEmpty {
            return labelWidth + valueWidth
        }
        return labelWidth + labelValueSpacing + valueWidth
    }

    private static func textSize(_ text: String) -> NSSize {
        guard !text.isEmpty else {
            return .zero
        }

        return NSAttributedString(string: text, attributes: [
            .font: font,
            .kern: 0
        ]).size()
    }
}
