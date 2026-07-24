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
                    Button("Close") { dismiss() }
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
            Text(viewModel.isSignUpMode ? "Create account" : "Welcome back")
                .titleStyle()

            Text(
                viewModel.isSignUpMode
                    ? "Sign up with email to start saving memories."
                    : "Sign in with your email and password."
            )
            .secondaryStyle()
        }
    }

    private var fields: some View {
        VStack(spacing: Spacing.md) {
            ThemeTextField(
                text: $viewModel.email,
                placeholder: "Email",
                maxLength: 254
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocorrectionDisabled()

            ThemeTextField(
                text: $viewModel.password,
                placeholder: "Password",
                maxLength: 128,
                isSecure: true
            )
            .textContentType(viewModel.isSignUpMode ? .newPassword : .password)

            if !viewModel.isSignUpMode {
                Button("Forgot password?") {
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
                title: viewModel.isSignUpMode ? "Sign up" : "Sign in",
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.canSubmit
            ) {
                submitRequestID += 1
            }

            Button(action: viewModel.toggleMode) {
                Text(
                    viewModel.isSignUpMode
                        ? "Already have an account? Sign in"
                        : "Need an account? Sign up"
                )
                .font(.theme.body)
                .foregroundStyle(Color.theme.accent)
            }
            .buttonStyle(.plain)
        }
    }
}
