import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var isSigningOut = false
    @Published private(set) var isDeletingAccount = false
    @Published private(set) var errorMessage: String?
    @Published var showDeleteAccountWarning = false
    @Published var showDeleteAccountConfirm = false
    @Published var deleteConfirmationText = ""

    private let authManager: AuthManagerProtocol
    private let deleteAccountUseCase: DeleteAccountUseCaseProtocol
    private let requiredDeletePhrase = "DELETE"

    init(
        authManager: AuthManagerProtocol,
        deleteAccountUseCase: DeleteAccountUseCaseProtocol
    ) {
        self.authManager = authManager
        self.deleteAccountUseCase = deleteAccountUseCase
    }

    var signedInEmail: String? {
        authManager.currentUser?.email
    }

    var canConfirmAccountDeletion: Bool {
        deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == requiredDeletePhrase
    }

    func signOut() async {
        isSigningOut = true
        errorMessage = nil
        defer { isSigningOut = false }

        do {
            try await authManager.signOut()
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = AppError.authFailed(underlying: error).errorDescription
        }
    }

    func beginDeleteAccount() {
        errorMessage = nil
        deleteConfirmationText = ""
        showDeleteAccountWarning = true
    }

    func continueDeleteAccountAfterWarning() {
        showDeleteAccountWarning = false
        deleteConfirmationText = ""
        showDeleteAccountConfirm = true
    }

    func cancelDeleteAccount() {
        showDeleteAccountWarning = false
        showDeleteAccountConfirm = false
        deleteConfirmationText = ""
    }

    func confirmDeleteAccount() async {
        guard canConfirmAccountDeletion else { return }
        guard let userId = authManager.currentUser?.id else {
            errorMessage = L10n.Error.notAuthenticated
            return
        }

        showDeleteAccountConfirm = false
        isDeletingAccount = true
        errorMessage = nil
        defer { isDeletingAccount = false }

        do {
            try await deleteAccountUseCase.execute(userId: userId)
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = AppError.authFailed(underlying: error).errorDescription
                ?? L10n.Settings.deleteAccountFailed
        }
    }
}
