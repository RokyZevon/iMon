import AppKit
import Foundation
import iMonCore

public enum MenuBarAttributedTitleFactory {
    public static let lineHeight: CGFloat = 11
    public static let baselineOffset: CGFloat = -4.5
    public static let horizontalPadding: CGFloat = 6

    public static func attributedTitle(for title: MenuBarStackedTitle) -> NSAttributedString {
        attributedTitle(for: title, memoryPressure: nil)
    }

    public static func attributedTitle(
        for title: MenuBarStackedTitle,
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
}
