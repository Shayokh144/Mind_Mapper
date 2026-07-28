import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var isSigningOut = false
    @Published private(set) var errorMessage: String?

    private let authManager: AuthManagerProtocol

    init(authManager: AuthManagerProtocol) {
        self.authManager = authManager
    }

    var signedInEmail: String? {
        authManager.currentUser?.email
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
}
