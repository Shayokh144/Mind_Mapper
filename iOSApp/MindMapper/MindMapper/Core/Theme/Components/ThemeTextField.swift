import SwiftUI

struct ThemeTextField: View {
    @Binding var text: String
    let placeholder: String
    var maxLength: Int = 500

    var body: some View {
        HStack(spacing: Spacing.sm) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.theme.body)
                .foregroundStyle(Color.theme.textPrimary)
                .lineLimit(1...4)
                .onChange(of: text) { newValue in
                    if newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(Color.theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
    }
}

#Preview("Light") {
    ThemeTextField(text: .constant(""), placeholder: "Tell me something or ask...")
        .padding(Spacing.lg)
        .background(Color.theme.background)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ThemeTextField(text: .constant(""), placeholder: "Tell me something or ask...")
        .padding(Spacing.lg)
        .background(Color.theme.background)
        .preferredColorScheme(.dark)
}
