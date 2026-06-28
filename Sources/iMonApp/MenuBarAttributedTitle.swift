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
