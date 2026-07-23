import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                labelContent
            }
            .foregroundStyle(Color.theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isEnabled ? Color.theme.accent : Color.theme.textMuted)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(ThemePressButtonStyle(filled: true))
        .disabled(!isEnabled || isLoading)
    }

    @ViewBuilder
    private var labelContent: some View {
        if isLoading {
            ProgressView()
                .tint(Color.theme.onAccent)
        } else {
            titleContent
        }
    }

    @ViewBuilder
    private var titleContent: some View {
        if let icon {
            Image(systemName: icon)
                .font(.theme.iconButton)
        }
        Text(title)
            .font(.theme.headline)
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.lg) {
        PrimaryButton(title: "Continue", action: {})
        PrimaryButton(title: "Save memory", icon: "checkmark", action: {})
        PrimaryButton(title: "Loading...", isLoading: true, action: {})
        PrimaryButton(title: "Disabled", isEnabled: false, action: {})
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: Spacing.lg) {
        PrimaryButton(title: "Continue", action: {})
        PrimaryButton(title: "Save memory", icon: "checkmark", action: {})
        PrimaryButton(title: "Loading...", isLoading: true, action: {})
        PrimaryButton(title: "Disabled", isEnabled: false, action: {})
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.dark)
}
