import Foundation
import Combine
import Auth
import Supabase

@MainActor
final class AuthManager: ObservableObject, AuthManagerProtocol {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isRestoringSession = true
    @Published private(set) var currentUser: User?

    private let client: SupabaseClient
    private let authRepository: AuthRepositoryProtocol

    init(client: SupabaseClient, authRepository: AuthRepositoryProtocol) {
        self.client = client
        self.authRepository = authRepository
    }

    func signUp(email: String, password: String) async throws {
        try await performAuth("signUp") {
            let response = try await client.auth.signUp(email: email, password: password)
            guard let session = response.session else {
                throw AppError.emailConfirmationRequired
            }
            try await persistAuthenticatedUser(from: session.user, fallbackEmail: email)
        }
    }

    func signIn(email: String, password: String) async throws {
        try await performAuth("signIn") {
            let session = try await client.auth.signIn(email: email, password: password)
            try await persistAuthenticatedUser(from: session.user, fallbackEmail: email)
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            AppLogger.error("signOut failed", error: error)
            throw AppError.authFailed(underlying: error)
        }
    }

    func restoreSession() async {
        isRestoringSession = true
        defer { isRestoringSession = false }

        do {
            let session = try await client.auth.session
            guard !session.isExpired else {
                await clearLocalAuth(reason: "Stored Supabase session is expired")
                return
            }
            // Local tokens can outlive a user deleted in the Supabase dashboard.
            // `user()` hits the Auth API and fails if the account no longer exists.
            _ = try await client.auth.user()
            try await applyRestoredSession(session)
            isAuthenticated = true
        } catch {
            AppLogger.info("No valid Supabase session to restore")
            await clearLocalAuth(reason: nil)
        }
    }

    // MARK: - Private

    private func clearLocalAuth(reason: String?) async {
        if let reason {
            AppLogger.info(reason)
        }
        do {
            try await client.auth.signOut()
        } catch {
            // Still drop local UI state if remote logout fails (e.g. user already deleted).
            AppLogger.error("Failed to clear Supabase session during restore", error: error)
        }
        currentUser = nil
        isAuthenticated = false
    }
    private func performAuth(
        _ operation: String,
        _ work: () async throws -> Void
    ) async throws {
        do {
            try await work()
        } catch let error as AppError {
            throw error
        } catch {
            AppLogger.error("\(operation) failed", error: error)
            throw Self.mapAuthError(error)
        }
    }

    private func applyRestoredSession(_ session: Auth.Session) async throws {
        let userId = session.user.id.uuidString
        if let local = try await authRepository.fetch(id: userId) {
            currentUser = local
            return
        }
        try await persistAuthenticatedUser(
            from: session.user,
            fallbackEmail: session.user.email ?? ""
        )
    }

    private func persistAuthenticatedUser(
        from authUser: Auth.User,
        fallbackEmail: String
    ) async throws {
        let email = authUser.email ?? fallbackEmail
        let user = User(
            id: authUser.id.uuidString,
            email: email,
            displayName: nil,
            createdAt: authUser.createdAt
        )
        try await authRepository.upsert(user)
        currentUser = user
        isAuthenticated = true
    }

    private static func mapAuthError(_ error: Error) -> AppError {
        let message = String(describing: error).lowercased()
        if message.contains("invalid login")
            || message.contains("invalid_credentials")
            || message.contains("invalid email or password")
        {
            return .invalidCredentials
        }
        if message.contains("email not confirmed") {
            return .emailConfirmationRequired
        }
        return .authFailed(underlying: error)
    }
}
