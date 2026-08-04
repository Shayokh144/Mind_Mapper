import SwiftUI

struct ThemeBadge: View {
    let text: String
    var icon: String? = nil
    var role: Role = .accent
    /// When set, overrides `role.color` (e.g. custom session tags).
    var tint: Color? = nil

    enum Role {
        case accent, success, warning, danger, neutral

        var color: Color {
            switch self {
            case .accent: return Color.theme.accent
            case .success: return Color.theme.success
            case .warning: return Color.theme.warning
            case .danger: return Color.theme.danger
            case .neutral: return Color.theme.textSecondary
            }
        }
    }

    private var color: Color { tint ?? role.color }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.theme.iconBadge)
            }
            Text(text)
                .font(.theme.caption)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.sm) {
        ThemeBadge(text: "Found across 2 conversations", icon: "sparkles", role: .accent)
        ThemeBadge(text: "Saved", icon: "checkmark", role: .success)
        ThemeBadge(text: "Out of scope", icon: "exclamationmark.triangle", role: .warning)
        ThemeBadge(text: "Failed", icon: "xmark", role: .danger)
        ThemeBadge(text: "Draft", role: .neutral)
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: Spacing.sm) {
        ThemeBadge(text: "Found across 2 conversations", icon: "sparkles", role: .accent)
        ThemeBadge(text: "Saved", icon: "checkmark", role: .success)
        ThemeBadge(text: "Out of scope", icon: "exclamationmark.triangle", role: .warning)
        ThemeBadge(text: "Failed", icon: "xmark", role: .danger)
        ThemeBadge(text: "Draft", role: .neutral)
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.dark)
}
