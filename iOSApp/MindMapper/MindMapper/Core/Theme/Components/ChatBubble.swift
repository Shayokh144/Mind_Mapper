import SwiftUI

struct ChatBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            Text(text)
                .font(.theme.body)
                .foregroundStyle(isUser ? Color.theme.onAccent : Color.theme.textPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(isUser ? Color.theme.accent : Color.theme.surface)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Radius.lg,
                        bottomLeadingRadius: isUser ? Radius.lg : Spacing.xs,
                        bottomTrailingRadius: isUser ? Spacing.xs : Radius.lg,
                        topTrailingRadius: Radius.lg,
                        style: .continuous
                    )
                )

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.md) {
        ChatBubble(text: "Where is my blue T-shirt?", isUser: true)
        ChatBubble(text: "Your blue T-shirt is in the 3rd drawer.", isUser: false)
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: Spacing.md) {
        ChatBubble(text: "Where is my blue T-shirt?", isUser: true)
        ChatBubble(text: "Your blue T-shirt is in the 3rd drawer.", isUser: false)
    }
    .padding(Spacing.lg)
    .background(Color.theme.background)
    .preferredColorScheme(.dark)
}
