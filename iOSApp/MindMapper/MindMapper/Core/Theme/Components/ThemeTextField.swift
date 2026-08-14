import SwiftUI

struct ThemeTextField: View {
    @Binding var text: String
    let placeholder: String
    var maxLength: Int = 500
    var isSecure: Bool = false
    var isEnabled: Bool = true
    var focus: FocusState<Bool>.Binding? = nil

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .font(.theme.body)
            .foregroundStyle(isEnabled ? Color.theme.textPrimary : Color.theme.textMuted)
            .disabled(!isEnabled)
            .modifier(OptionalFocusModifier(focus: isEnabled ? focus : nil))
            .onChange(of: text) { newValue in
                if newValue.count > maxLength {
                    text = String(newValue.prefix(maxLength))
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(Color.theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .opacity(isEnabled ? 1 : 0.7)
        .allowsHitTesting(isEnabled)
    }
}

private struct OptionalFocusModifier: ViewModifier {
    var focus: FocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let focus {
            content.focused(focus)
        } else {
            content
        }
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
