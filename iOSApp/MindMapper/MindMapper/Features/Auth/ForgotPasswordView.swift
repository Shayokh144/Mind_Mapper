import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var viewModel: ForgotPasswordViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var submitRequestID = 0

    init(viewModel: ForgotPasswordViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Reset password")
                        .titleStyle()

                    Text("Enter your email and we'll send a link to reset your password.")
                        .secondaryStyle()

                    ThemeTextField(
                        text: $viewModel.email,
                        placeholder: "Email",
                        maxLength: 254
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()

                    if let successMessage = viewModel.successMessage {
                        ThemeBadge(text: successMessage, icon: "checkmark.circle", role: .success)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        ThemeBadge(text: errorMessage, icon: "xmark.circle", role: .danger)
                    }

                    PrimaryButton(
                        title: "Send reset link",
                        isLoading: viewModel.isLoading,
                        isEnabled: viewModel.canSubmit
                    ) {
                        submitRequestID += 1
                    }
                }
                .padding(Spacing.xl)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.theme.accent)
                }
            }
            .task(id: submitRequestID) {
                guard submitRequestID > 0 else { return }
                await viewModel.submit()
            }
        }
    }
}
