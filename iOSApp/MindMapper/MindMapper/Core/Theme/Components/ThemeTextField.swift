import SwiftUI

struct ThemeTextField: View {
    @Binding var text: String
    let placeholder: String
    var maxLength: Int = 500
    var isSecure: Bool = false
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
            .foregroundStyle(Color.theme.textPrimary)
            .modifier(OptionalFocusModifier(focus: focus))
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
