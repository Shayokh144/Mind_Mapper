import SwiftUI

struct ChatBubble: View {
    let text: String
    let isUser: Bool
    /// Scope-blocked / caution replies — warning border on assistant bubbles.
    var isWarning: Bool = false

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            Text(text)
                .font(.theme.body)
                .foregroundStyle(foreground)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(background)
                .clipShape(bubbleShape)
                .overlay(
                    bubbleShape
                        .strokeBorder(borderColor, lineWidth: isWarning && !isUser ? 1.5 : 0)
                )

            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var foreground: Color {
        if isUser { return Color.theme.onAccent }
        return Color.theme.textPrimary
    }

    private var background: Color {
        if isUser { return Color.theme.accent }
        if isWarning { return Color.theme.warning.opacity(0.12) }
        return Color.theme.surface
    }

    private var borderColor: Color {
        isWarning ? Color.theme.warning : .clear
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: Radius.lg,
            bottomLeadingRadius: isUser ? Radius.lg : Spacing.xs,
            bottomTrailingRadius: isUser ? Spacing.xs : Radius.lg,
            topTrailingRadius: Radius.lg,
            style: .continuous
        )
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.md) {
        ChatBubble(text: "Where is my blue T-shirt?", isUser: true)
        ChatBubble(text: "Your blue T-shirt is in the 3rd drawer.", isUser: false)
        ChatBubble(text: "I can only help with personal notes and memories.", isUser: false, isWarning: true)
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: Spacing.md) {
        ChatBubble(text: "Where is my blue T-shirt?", isUser: true)
        ChatBubble(text: "Your blue T-shirt is in the 3rd drawer.", isUser: false)
        ChatBubble(text: "I can only help with personal notes and memories.", isUser: false, isWarning: true)
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.dark)
}
