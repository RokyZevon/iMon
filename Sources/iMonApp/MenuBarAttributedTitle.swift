import AppKit
import Foundation
import iMonCore

public enum MenuBarAttributedTitleFactory {
    public static let lineHeight: CGFloat = 11
    public static let baselineOffset: CGFloat = -4.5
    public static let horizontalPadding: CGFloat = 6

    public static func attributedTitle(for title: MenuBarStackedTitle) -> NSAttributedString {
        attributedTitle(for: title, cpuLoad: nil, memoryPressure: nil)
    }

    public static func attributedTitle(
        for title: MenuBarStackedTitle,
        memoryPressure: MemoryPressureLevel?
    ) -> NSAttributedString {
        attributedTitle(for: title, cpuLoad: nil, memoryPressure: memoryPressure)
    }

    public static func attributedTitle(
        for title: MenuBarStackedTitle,
        cpuLoad: CPULoadPressure?,
        memoryPressure: MemoryPressureLevel?
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.minimumLineHeight = lineHeight

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .semibold),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.labelColor,
            .baselineOffset: baselineOffset,
            .kern: 0
        ]

        let attributedTitle = NSMutableAttributedString(string: title.stringValue, attributes: attributes)
        if let cpuLoad, cpuLoad.isAvailable {
            let loadValue = MetricFormatter.compactLoadPressure(cpuLoad)
            if let range = valueRange(after: "L", value: loadValue, in: title.stringValue) {
                attributedTitle.addAttribute(
                    .foregroundColor,
                    value: loadColor(for: cpuLoad.level),
                    range: range
                )
            }
        }

        if let memoryPressure {
            let pressureLabel = MetricFormatter.compactMemoryPressure(memoryPressure).trimmingCharacters(in: .whitespaces)
            let range = (title.stringValue as NSString).range(of: pressureLabel)
            if range.location != NSNotFound {
                attributedTitle.addAttribute(
                    .foregroundColor,
                    value: pressureColor(for: memoryPressure),
                    range: range
                )
            }
        }

        return attributedTitle
    }

    public static func statusItemLength(for attributedTitle: NSAttributedString) -> CGFloat {
        ceil(attributedTitle.size().width) + horizontalPadding * 2
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

    private static func valueRange(after label: String, value: String, in string: String) -> NSRange? {
        let nsString = string as NSString
        let labelRange = nsString.range(of: label)
        guard labelRange.location != NSNotFound else {
            return nil
        }

        let searchStart = labelRange.location + labelRange.length
        let searchRange = NSRange(location: searchStart, length: nsString.length - searchStart)
        let valueRange = nsString.range(of: value, options: [], range: searchRange)
        guard valueRange.location != NSNotFound else {
            return nil
        }

        return valueRange
    }
}
