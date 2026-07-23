import Foundation

@MainActor
protocol AuthManagerProtocol: AnyObject {
    var isAuthenticated: Bool { get }
    var isRestoringSession: Bool { get }
    var currentUser: User? { get }

    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async throws
    func restoreSession() async
}
