import SwiftUI

/// Thin usage meter for session message cap (`ChatLimits.maxMessagesPerSession`).
/// Fill grows with usage; color shifts success → warning → danger.
struct SessionMessageQuotaBar: View {
    let usedCount: Int
    let maxCount: Int

    private var fraction: CGFloat {
        guard maxCount > 0 else { return 0 }
        return min(1, CGFloat(usedCount) / CGFloat(maxCount))
    }

    private var fillColor: Color {
        switch fraction {
        case ..<0.55:
            return Color.theme.success
        case ..<0.8:
            return Color.theme.warning
        default:
            return Color.theme.danger
        }
    }

    private var remaining: Int {
        max(0, maxCount - usedCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.theme.surfaceSecondary)
                    Capsule()
                        .fill(fillColor)
                        .frame(width: max(0, geo.size.width * fraction))
                        .animation(.easeInOut(duration: 0.25), value: fraction)
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)

            Text(L10n.Chat.messagesRemaining(remaining, max: maxCount))
                .font(.theme.caption)
                .foregroundStyle(fillColor)
                .accessibilityLabel(L10n.Chat.messagesRemainingAccessibility(remaining, max: maxCount))
        }
    }
}

#Preview("Low usage") {
    SessionMessageQuotaBar(usedCount: 4, maxCount: 40)
        .padding(Spacing.lg)
        .background(Color.theme.background)
}

#Preview("High usage") {
    SessionMessageQuotaBar(usedCount: 34, maxCount: 40)
        .padding(Spacing.lg)
        .background(Color.theme.background)
}
