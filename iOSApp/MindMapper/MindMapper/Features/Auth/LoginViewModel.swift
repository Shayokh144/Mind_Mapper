import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSignUpMode = false

    private let authManager: AuthManagerProtocol

    init(authManager: AuthManagerProtocol) {
        self.authManager = authManager
    }

    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 6
            && !isLoading
    }

    func toggleMode() {
        isSignUpMode.toggle()
        errorMessage = nil
    }

    func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if isSignUpMode {
                try await authManager.signUp(email: trimmedEmail, password: password)
            } else {
                try await authManager.signIn(email: trimmedEmail, password: password)
            }
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = AppError.authFailed(underlying: error).errorDescription
        }
    }
}
