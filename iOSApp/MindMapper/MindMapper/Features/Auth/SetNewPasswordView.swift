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
                    Text(L10n.Auth.chooseNewPassword)
                        .titleStyle()

                    Text(L10n.Auth.chooseNewPasswordSubtitle)
                        .secondaryStyle()

                    ThemeTextField(
                        text: $viewModel.password,
                        placeholder: L10n.Auth.newPassword,
                        maxLength: 128,
                        isSecure: true
                    )
                    .textContentType(.newPassword)

                    ThemeTextField(
                        text: $viewModel.confirmPassword,
                        placeholder: L10n.Auth.confirmPassword,
                        maxLength: 128,
                        isSecure: true
                    )
                    .textContentType(.newPassword)

                    if let errorMessage = viewModel.errorMessage {
                        ThemeBadge(text: errorMessage, icon: "xmark.circle", role: .danger)
                    }

                    PrimaryButton(
                        title: L10n.Auth.updatePassword,
                        isLoading: viewModel.isLoading,
                        isEnabled: viewModel.canSubmit
                    ) {
                        submitRequestID += 1
                    }
                }
                .padding(Spacing.xl)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle(L10n.Auth.resetPassword)
            .task(id: submitRequestID) {
                guard submitRequestID > 0 else { return }
                await viewModel.submit()
            }
        }
    }
}
