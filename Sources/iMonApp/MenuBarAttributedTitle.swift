import AppKit
import Foundation
import iMonCore

public enum MenuBarAttributedTitleFactory {
    public static let lineHeight: CGFloat = 11
    public static let baselineOffset: CGFloat = -4.5
    public static let horizontalPadding: CGFloat = 6

    public static func attributedTitle(for title: MenuBarStackedTitle) -> NSAttributedString {
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

        return NSAttributedString(string: title.stringValue, attributes: attributes)
    }

    public static func statusItemLength(for attributedTitle: NSAttributedString) -> CGFloat {
        ceil(attributedTitle.size().width) + horizontalPadding * 2
    }
}
