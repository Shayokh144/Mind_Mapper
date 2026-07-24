import Foundation

@MainActor
protocol AuthManagerProtocol: AnyObject {
    var isAuthenticated: Bool { get }
    var isRestoringSession: Bool { get }
    var pendingPasswordReset: Bool { get }
    var currentUser: User? { get }
    var deepLinkErrorMessage: String? { get }
    /// True when local session was kept but remote validation could not run (e.g. offline).
    var needsRemoteRevalidation: Bool { get }

    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async throws
    func restoreSession() async
    /// Re-runs remote session checks after connectivity returns. No-op if not needed.
    func revalidateSessionIfNeeded() async
    func requestPasswordReset(email: String) async throws
    func updatePassword(_ newPassword: String) async throws
    func handleAuthCallback(url: URL) async
    func clearDeepLinkError()
}
