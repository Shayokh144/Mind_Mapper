import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var signOutRequestID = 0
    @State private var deleteAccountRequestID = 0

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

                notificationSection

                if let errorMessage = viewModel.errorMessage {
                    ThemeBadge(text: errorMessage, icon: "xmark.circle", role: .danger)
                }

                SecondaryButton(title: L10n.Settings.signOut) {
                    signOutRequestID += 1
                }
                .disabled(viewModel.isSigningOut || viewModel.isDeletingAccount)
                .opacity(viewModel.isSigningOut ? 0.6 : 1)

                Spacer()

                DestructiveButton(
                    title: L10n.Settings.deleteAccount,
                    style: .outlined
                ) {
                    viewModel.beginDeleteAccount()
                }
                .disabled(viewModel.isDeletingAccount || viewModel.isSigningOut)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle(L10n.Settings.title)
            .confirmationDialog(
                L10n.Settings.deleteAccountWarningTitle,
                isPresented: $viewModel.showDeleteAccountWarning,
                titleVisibility: .visible
            ) {
                Button(L10n.Settings.deleteAccountContinue, role: .destructive) {
                    viewModel.continueDeleteAccountAfterWarning()
                }
                Button(L10n.Common.close, role: .cancel) {
                    viewModel.cancelDeleteAccount()
                }
            } message: {
                Text(L10n.Settings.deleteAccountWarningMessage)
            }
            .sheet(isPresented: $viewModel.showDeleteAccountConfirm) {
                deleteConfirmSheet
            }
            .task(id: signOutRequestID) {
                guard signOutRequestID > 0 else { return }
                await viewModel.signOut()
            }
            .task(id: deleteAccountRequestID) {
                guard deleteAccountRequestID > 0 else { return }
                await viewModel.confirmDeleteAccount()
            }
            .task {
                await viewModel.refreshNotificationStatus()
            }
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(L10n.Settings.notificationsTitle)
                .headlineStyle()
            Text(viewModel.notificationStatusText)
                .secondaryStyle()
            if viewModel.showsOpenSettingsForNotifications {
                SecondaryButton(title: L10n.Settings.openSystemSettings) {
                    openSystemSettings()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var deleteConfirmSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(L10n.Settings.deleteAccountConfirmTitle)
                    .headlineStyle()

                Text(L10n.Settings.deleteAccountConfirmMessage)
                    .secondaryStyle()

                ThemeTextField(
                    text: $viewModel.deleteConfirmationText,
                    placeholder: L10n.Settings.deleteAccountConfirmPlaceholder,
                    maxLength: 16
                )
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

                DestructiveButton(title: L10n.Settings.deleteAccountConfirmAction) {
                    deleteAccountRequestID += 1
                }
                .disabled(!viewModel.canConfirmAccountDeletion || viewModel.isDeletingAccount)
                .opacity(viewModel.canConfirmAccountDeletion ? 1 : 0.5)

                Spacer()
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle(L10n.Settings.deleteAccount)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) {
                        viewModel.cancelDeleteAccount()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
