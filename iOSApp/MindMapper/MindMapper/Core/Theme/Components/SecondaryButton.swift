import SwiftUI

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.theme.iconButtonMedium)
                }
                Text(title)
                    .font(.theme.headline)
            }
            .foregroundStyle(Color.theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(ThemePressButtonStyle(filled: false))
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.md) {
        SecondaryButton(title: "Cancel", action: {})
        SecondaryButton(title: "Add photo", icon: "photo", action: {})
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: Spacing.md) {
        SecondaryButton(title: "Cancel", action: {})
        SecondaryButton(title: "Add photo", icon: "photo", action: {})
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.dark)
}
