import Foundation
import Combine

@MainActor
final class SetNewPasswordViewModel: ObservableObject {
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authManager: AuthManagerProtocol
    private let networkReachability: NetworkReachabilityProtocol

    init(
        authManager: AuthManagerProtocol,
        networkReachability: NetworkReachabilityProtocol
    ) {
        self.authManager = authManager
        self.networkReachability = networkReachability
    }

    var canSubmit: Bool {
        password.count >= 6 && !isLoading
    }

    func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard password == confirmPassword else {
            errorMessage = AppError.passwordsDoNotMatch.errorDescription
            return
        }

        do {
            try NetworkGate.requireConnection(networkReachability)
            try await authManager.updatePassword(password)
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = AppError.authFailed(underlying: error).errorDescription
        }
    }
}
