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
                    Text(L10n.Brand.name)
                        .font(.theme.largeTitle)
                        .foregroundStyle(Color.theme.textPrimary)

                    Text(L10n.Onboarding.tagline)
                        .font(.theme.body)
                        .foregroundStyle(Color.theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: Spacing.md) {
                    featureRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        text: L10n.Onboarding.featureChat
                    )
                    featureRow(
                        icon: "sparkles",
                        text: L10n.Onboarding.featureRecall
                    )
                    featureRow(
                        icon: "lock.shield.fill",
                        text: L10n.Onboarding.featurePrivacy
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.md)
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            VStack(spacing: Spacing.md) {
                PrimaryButton(title: L10n.Onboarding.continueEmail) {
                    showLogin = true
                }

                Text(L10n.Onboarding.legal)
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
                .environmentObject(container)
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
