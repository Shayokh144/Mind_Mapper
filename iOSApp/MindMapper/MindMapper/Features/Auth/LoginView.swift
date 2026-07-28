import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var submitRequestID = 0
    @State private var showForgotPassword = false

    init(viewModel: LoginViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    fields
                    if let errorMessage = viewModel.errorMessage {
                        ThemeBadge(text: errorMessage, icon: "xmark.circle", role: .danger)
                    }
                    actions
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
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(viewModel: container.makeForgotPasswordViewModel())
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text(viewModel.isSignUpMode ? L10n.Auth.createAccount : L10n.Auth.welcomeBack)
                .titleStyle()

            Text(
                viewModel.isSignUpMode
                    ? L10n.Auth.signUpSubtitle
                    : L10n.Auth.signInSubtitle
            )
            .secondaryStyle()
        }
    }

    private var fields: some View {
        VStack(spacing: Spacing.md) {
            ThemeTextField(
                text: $viewModel.email,
                placeholder: L10n.Auth.email,
                maxLength: 254
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocorrectionDisabled()

            ThemeTextField(
                text: $viewModel.password,
                placeholder: L10n.Auth.password,
                maxLength: 128,
                isSecure: true
            )
            .textContentType(viewModel.isSignUpMode ? .newPassword : .password)

            if !viewModel.isSignUpMode {
                Button(L10n.Auth.forgotPassword) {
                    showForgotPassword = true
                }
                .font(.theme.body)
                .foregroundStyle(Color.theme.accent)
                .buttonStyle(.plain)
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            PrimaryButton(
                title: viewModel.isSignUpMode ? L10n.Auth.signUp : L10n.Auth.signIn,
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.canSubmit
            ) {
                submitRequestID += 1
            }

            Button(action: viewModel.toggleMode) {
                Text(
                    viewModel.isSignUpMode
                        ? L10n.Auth.haveAccount
                        : L10n.Auth.needAccount
                )
                .font(.theme.body)
                .foregroundStyle(Color.theme.accent)
            }
            .buttonStyle(.plain)
        }
    }
}
