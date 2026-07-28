import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var signOutRequestID = 0

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Text(L10n.Settings.title)
                    .titleStyle()

                if let email = viewModel.signedInEmail {
                    Text(email)
                        .secondaryStyle()
                }

                if let errorMessage = viewModel.errorMessage {
                    ThemeBadge(text: errorMessage, icon: "xmark.circle", role: .danger)
                }

                PrimaryButton(
                    title: L10n.Settings.signOut,
                    isLoading: viewModel.isSigningOut
                ) {
                    signOutRequestID += 1
                }

                Spacer()
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle(L10n.Settings.title)
            .task(id: signOutRequestID) {
                guard signOutRequestID > 0 else { return }
                await viewModel.signOut()
            }
        }
    }
}
