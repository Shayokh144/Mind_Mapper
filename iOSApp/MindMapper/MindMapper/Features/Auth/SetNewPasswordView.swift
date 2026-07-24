import SwiftUI

struct SetNewPasswordView: View {
    @StateObject private var viewModel: SetNewPasswordViewModel
    @State private var submitRequestID = 0

    init(viewModel: SetNewPasswordViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Choose a new password")
                        .titleStyle()

                    Text("Enter a new password for your account.")
                        .secondaryStyle()

                    ThemeTextField(
                        text: $viewModel.password,
                        placeholder: "New password",
                        maxLength: 128,
                        isSecure: true
                    )
                    .textContentType(.newPassword)

                    ThemeTextField(
                        text: $viewModel.confirmPassword,
                        placeholder: "Confirm password",
                        maxLength: 128,
                        isSecure: true
                    )
                    .textContentType(.newPassword)

                    if let errorMessage = viewModel.errorMessage {
                        ThemeBadge(text: errorMessage, icon: "xmark.circle", role: .danger)
                    }

                    PrimaryButton(
                        title: "Update password",
                        isLoading: viewModel.isLoading,
                        isEnabled: viewModel.canSubmit
                    ) {
                        submitRequestID += 1
                    }
                }
                .padding(Spacing.xl)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle("Reset password")
            .task(id: submitRequestID) {
                guard submitRequestID > 0 else { return }
                await viewModel.submit()
            }
        }
    }
}
