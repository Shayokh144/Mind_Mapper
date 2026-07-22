import SwiftUI

struct GhostButton: View {
    let title: String
    var color: Color = Color.theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.theme.subheadline)
                .foregroundStyle(color)
        }
        .buttonStyle(ThemePressButtonStyle(filled: false))
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.md) {
        GhostButton(title: "Skip for now", action: {})
        GhostButton(title: "Learn more", color: Color.theme.textSecondary, action: {})
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: Spacing.md) {
        GhostButton(title: "Skip for now", action: {})
        GhostButton(title: "Learn more", color: Color.theme.textSecondary, action: {})
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.dark)
}
