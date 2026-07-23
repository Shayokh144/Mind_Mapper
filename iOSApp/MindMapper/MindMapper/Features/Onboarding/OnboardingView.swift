import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var showLogin = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.xxl)

            VStack(spacing: Spacing.xl) {
                Image(systemName: "brain.head.profile")
                    .font(.theme.largeTitle)
                    .foregroundStyle(Color.theme.accent)
                    .accessibilityHidden(true)

                VStack(spacing: Spacing.sm) {
                    Text("Mind Mapper")
                        .font(.theme.largeTitle)
                        .foregroundStyle(Color.theme.textPrimary)

                    Text("Remember what matters across every conversation.")
                        .font(.theme.body)
                        .foregroundStyle(Color.theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: Spacing.md) {
                    featureRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        text: "Chat naturally — store or recall memories"
                    )
                    featureRow(
                        icon: "sparkles",
                        text: "Smart recall from past sessions"
                    )
                    featureRow(
                        icon: "lock.shield.fill",
                        text: "Your data stays under your control"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.md)
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            VStack(spacing: Spacing.md) {
                PrimaryButton(title: "Continue with email") {
                    showLogin = true
                }

                Text("By continuing, you agree to our Terms and Privacy Policy.")
                    .font(.theme.caption)
                    .foregroundStyle(Color.theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background.ignoresSafeArea())
        .sheet(isPresented: $showLogin) {
            LoginView(viewModel: container.makeLoginViewModel())
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.theme.iconButton)
                .foregroundStyle(Color.theme.accent)
                .frame(width: 24)
            Text(text)
                .font(.theme.body)
                .foregroundStyle(Color.theme.textPrimary)
        }
    }
}
