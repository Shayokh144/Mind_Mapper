import Foundation
@testable import MindMapper

@MainActor
final class MockAuthManager: AuthManagerProtocol {
    var isAuthenticated = false
    var isRestoringSession = false
    var pendingPasswordReset = false
    var currentUser: User?
    var deepLinkErrorMessage: String?
    var needsRemoteRevalidation = false

    private(set) var signInCallCount = 0
    private(set) var signUpCallCount = 0
    private(set) var requestPasswordResetCallCount = 0
    private(set) var updatePasswordCallCount = 0
    private(set) var revalidateCallCount = 0

    var signInError: Error?
    var signUpError: Error?

    func signUp(email: String, password: String) async throws {
        signUpCallCount += 1
        if let signUpError { throw signUpError }
        isAuthenticated = true
    }

    func signIn(email: String, password: String) async throws {
        signInCallCount += 1
        if let signInError { throw signInError }
        isAuthenticated = true
    }

    func signOut() async throws {
        isAuthenticated = false
    }

    func restoreSession() async {}

    func revalidateSessionIfNeeded() async {
        revalidateCallCount += 1
    }

    func requestPasswordReset(email: String) async throws {
        requestPasswordResetCallCount += 1
        throw AppError.passwordResetEmailSent
    }

    func updatePassword(_ newPassword: String) async throws {
        updatePasswordCallCount += 1
    }

    func handleAuthCallback(url: URL) async {}

    func clearDeepLinkError() {
        deepLinkErrorMessage = nil
    }
}
