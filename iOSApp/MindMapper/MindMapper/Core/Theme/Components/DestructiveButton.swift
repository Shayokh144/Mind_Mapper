import SwiftUI

struct DestructiveButton: View {
    let title: String
    var style: Style = .filled
    let action: () -> Void

    enum Style { case filled, outlined }

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(.theme.headline)
                .foregroundStyle(style == .filled ? Color.theme.onAccent : Color.theme.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(style == .filled ? Color.theme.danger : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(style == .outlined ? Color.theme.danger : Color.clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(ThemePressButtonStyle(filled: style == .filled))
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.md) {
        DestructiveButton(title: "Delete conversation", action: {})
        DestructiveButton(title: "Delete conversation", style: .outlined, action: {})
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: Spacing.md) {
        DestructiveButton(title: "Delete conversation", action: {})
        DestructiveButton(title: "Delete conversation", style: .outlined, action: {})
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.dark)
}
