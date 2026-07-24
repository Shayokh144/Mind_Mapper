import Foundation
import Combine

@MainActor
final class ForgotPasswordViewModel: ObservableObject {
    @Published var email = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

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
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func submit() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try NetworkGate.requireConnection(networkReachability)
            try await authManager.requestPasswordReset(email: trimmed)
        } catch AppError.noInternet {
            errorMessage = AppError.noInternet.errorDescription
        } catch AppError.passwordResetEmailSent {
            successMessage = AppError.passwordResetEmailSent.errorDescription
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            // Anti-enumeration: unknown failures still look like a successful send.
            successMessage = AppError.passwordResetEmailSent.errorDescription
        }
    }
}
