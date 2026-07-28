import SwiftUI

/// Three animated dots in an assistant-bubble chrome — shown while `ChatViewModel.isLoading`.
struct TypingIndicator: View {
    @State private var isAnimating = false

    private let dotSize: CGFloat = 8

    var body: some View {
        HStack {
            HStack(spacing: Spacing.xs) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.theme.textMuted)
                        .frame(width: dotSize, height: dotSize)
                        .opacity(isAnimating ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: isAnimating
                        )
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.theme.surface)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: Radius.lg,
                    bottomLeadingRadius: Spacing.xs,
                    bottomTrailingRadius: Radius.lg,
                    topTrailingRadius: Radius.lg,
                    style: .continuous
                )
            )

            Spacer(minLength: 40)
        }
        .accessibilityLabel(L10n.Chat.typingAccessibility)
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview("Light") {
    TypingIndicator()
        .padding(Spacing.lg)
        .background(Color.theme.background)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    TypingIndicator()
        .padding(Spacing.lg)
        .background(Color.theme.background)
        .preferredColorScheme(.dark)
}
