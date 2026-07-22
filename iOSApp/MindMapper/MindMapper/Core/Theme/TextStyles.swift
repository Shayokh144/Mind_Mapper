import SwiftUI

extension View {
    func titleStyle() -> some View {
        self.font(.theme.title)
            .foregroundStyle(Color.theme.textPrimary)
    }

    func headlineStyle() -> some View {
        self.font(.theme.headline)
            .foregroundStyle(Color.theme.textPrimary)
    }

    func bodyStyle() -> some View {
        self.font(.theme.body)
            .foregroundStyle(Color.theme.textPrimary)
    }

    func secondaryStyle() -> some View {
        self.font(.theme.subheadline)
            .foregroundStyle(Color.theme.textSecondary)
    }

    func captionStyle() -> some View {
        self.font(.theme.caption)
            .foregroundStyle(Color.theme.textMuted)
    }
}
