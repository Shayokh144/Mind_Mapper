import SwiftUI

extension Font {
    enum theme {
        static let largeTitle = Font.system(size: 28, weight: .bold)
        static let title = Font.system(size: 22, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let callout = Font.system(size: 15, weight: .regular)
        static let subheadline = Font.system(size: 14, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 11, weight: .regular)

        // Emphasis variants — used sparingly
        static let bodyBold = Font.system(size: 16, weight: .semibold)
        static let headlineBold = Font.system(size: 17, weight: .bold)

        // Icon sizes used by theme components
        static let iconButton = Font.system(size: 16, weight: .semibold)
        static let iconButtonMedium = Font.system(size: 16, weight: .medium)
        static let iconBadge = Font.system(size: 11, weight: .medium)
    }
}
