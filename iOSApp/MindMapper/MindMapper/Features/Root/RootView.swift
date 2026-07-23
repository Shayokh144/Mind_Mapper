import SwiftUI

/// Temporary main shell until navigation (task 16) lands. Lets us verify sign-out.
struct RootView: View {
    @StateObject private var viewModel: RootViewModel
    @State private var signOutRequestID = 0

    init(viewModel: RootViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Text("You're signed in")
                    .titleStyle()

                if let email = viewModel.signedInEmail {
                    Text(email)
                        .secondaryStyle()
                }

                if let errorMessage = viewModel.errorMessage {
                    ThemeBadge(text: errorMessage, icon: "xmark.circle", role: .danger)
                }

                PrimaryButton(
                    title: "Sign out",
                    isLoading: viewModel.isSigningOut
                ) {
                    signOutRequestID += 1
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle("Mind Mapper")
            .task(id: signOutRequestID) {
                guard signOutRequestID > 0 else { return }
                await viewModel.signOut()
            }
        }
    }
}
