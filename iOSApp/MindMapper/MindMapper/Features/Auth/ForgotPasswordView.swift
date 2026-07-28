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
                    Text(L10n.Auth.resetPassword)
                        .titleStyle()

                    Text(L10n.Auth.resetSubtitle)
                        .secondaryStyle()

                    ThemeTextField(
                        text: $viewModel.email,
                        placeholder: L10n.Auth.email,
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
                        title: L10n.Auth.sendResetLink,
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
                    Button(L10n.Common.close) { dismiss() }
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
