import Foundation
import Combine
import Auth
import Supabase

@MainActor
final class AuthManager: ObservableObject, AuthManagerProtocol {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isRestoringSession = true
    @Published private(set) var pendingPasswordReset = false
    @Published private(set) var currentUser: User?
    @Published private(set) var deepLinkErrorMessage: String?
    @Published private(set) var needsRemoteRevalidation = false

    private let client: SupabaseClient
    private let authRepository: AuthRepositoryProtocol
    /// Set when the user requests a reset; PKCE redirects often omit `type=recovery`.
    private var expectPasswordRecovery = false

    init(client: SupabaseClient, authRepository: AuthRepositoryProtocol) {
        self.client = client
        self.authRepository = authRepository
    }

    func signUp(email: String, password: String) async throws {
        try await performAuth("signUp") {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                redirectTo: AppConfig.authCallbackURL
            )
            guard let session = response.session else {
                throw AppError.emailConfirmationRequired
            }
            try await persistAuthenticatedUser(from: session.user, fallbackEmail: email)
            needsRemoteRevalidation = false
        }
    }

    func signIn(email: String, password: String) async throws {
        try await performAuth("signIn") {
            let session = try await client.auth.signIn(email: email, password: password)
            try await persistAuthenticatedUser(from: session.user, fallbackEmail: email)
            needsRemoteRevalidation = false
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
            pendingPasswordReset = false
            currentUser = nil
            isAuthenticated = false
            needsRemoteRevalidation = false
        } catch {
            AppLogger.error("signOut failed", error: error)
            throw AppError.authFailed(underlying: error)
        }
    }

    func restoreSession() async {
        isRestoringSession = true
        defer { isRestoringSession = false }

        // Prefer local storage — `client.auth.session` may hit the network to refresh.
        guard let localSession = client.auth.currentSession else {
            AppLogger.info("No local Supabase session to restore")
            await clearLocalAuth(reason: nil, signOutRemote: false)
            return
        }

        do {
            try await applyRestoredSession(localSession)
            isAuthenticated = true
        } catch {
            AppLogger.error("Failed to apply local session to SQLite", error: error)
            await clearLocalAuth(reason: "Could not load local user for stored session", signOutRemote: false)
            return
        }

        await validateSessionRemotely()
    }

    func revalidateSessionIfNeeded() async {
        guard needsRemoteRevalidation, isAuthenticated else { return }
        await validateSessionRemotely()
    }

    func requestPasswordReset(email: String) async throws {
        expectPasswordRecovery = true
        do {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: AppConfig.authCallbackURL
            )
        } catch {
            AppLogger.error("requestPasswordReset failed", error: error)
        }
        // Always the same outcome for the UI (anti-enumeration).
        throw AppError.passwordResetEmailSent
    }

    func updatePassword(_ newPassword: String) async throws {
        guard newPassword.count >= 6 else {
            throw AppError.passwordTooShort
        }
        try await performAuth("updatePassword") {
            _ = try await client.auth.update(user: UserAttributes(password: newPassword))
            let session = try await client.auth.session
            try await persistAuthenticatedUser(
                from: session.user,
                fallbackEmail: session.user.email ?? "",
                markAuthenticated: true
            )
            pendingPasswordReset = false
            needsRemoteRevalidation = false
        }
    }

    func handleAuthCallback(url: URL) async {
        deepLinkErrorMessage = nil
        let isRecovery = Self.isPasswordRecoveryURL(url) || expectPasswordRecovery
        expectPasswordRecovery = false

        do {
            let session = try await client.auth.session(from: url)
            try await persistAuthenticatedUser(
                from: session.user,
                fallbackEmail: session.user.email ?? "",
                markAuthenticated: !isRecovery
            )
            if isRecovery {
                pendingPasswordReset = true
                isAuthenticated = false
                needsRemoteRevalidation = false
            } else {
                pendingPasswordReset = false
                needsRemoteRevalidation = false
            }
        } catch {
            AppLogger.error("handleAuthCallback failed", error: error)
            deepLinkErrorMessage = AppError.authDeepLinkFailed.errorDescription
            pendingPasswordReset = false
        }
    }

    func clearDeepLinkError() {
        deepLinkErrorMessage = nil
    }

    // MARK: - Private

    /// Refresh + `user()` when possible. Keeps local auth on transient/network errors.
    private func validateSessionRemotely() async {
        do {
            let session = try await client.auth.session
            // Local tokens can outlive a user deleted in the Supabase dashboard.
            _ = try await client.auth.user()
            try await applyRestoredSession(session)
            isAuthenticated = true
            needsRemoteRevalidation = false
        } catch {
            if AuthNetworkErrorClassifier.isTransientNetworkError(error) {
                AppLogger.info("Keeping local session; remote validation deferred (network)")
                needsRemoteRevalidation = true
                return
            }
            if AuthNetworkErrorClassifier.isHardAuthFailure(error) {
                await clearLocalAuth(
                    reason: "Remote session validation rejected stored credentials",
                    signOutRemote: true
                )
                return
            }
            // Unknown failure after a successful local restore — do not wipe the session.
            AppLogger.error(
                "Remote session validation failed; keeping local session",
                error: error
            )
            needsRemoteRevalidation = true
        }
    }

    private func clearLocalAuth(reason: String?, signOutRemote: Bool) async {
        if let reason {
            AppLogger.info(reason)
        }
        if signOutRemote {
            do {
                try await client.auth.signOut()
            } catch {
                AppLogger.error("Failed to clear Supabase session during restore", error: error)
            }
        }
        pendingPasswordReset = false
        currentUser = nil
        isAuthenticated = false
        needsRemoteRevalidation = false
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
        fallbackEmail: String,
        markAuthenticated: Bool = true
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
        if markAuthenticated {
            isAuthenticated = true
        }
    }

    private static func isPasswordRecoveryURL(_ url: URL) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = (components?.queryItems ?? []) + fragmentQueryItems(from: components?.fragment)
        if items.contains(where: { $0.name == "type" && $0.value == "recovery" }) {
            return true
        }
        // Some clients put type in the path or host query after verify.
        return url.absoluteString.lowercased().contains("type=recovery")
    }

    private static func fragmentQueryItems(from fragment: String?) -> [URLQueryItem] {
        guard let fragment, !fragment.isEmpty else { return [] }
        return fragment
            .split(separator: "&")
            .compactMap { pair -> URLQueryItem? in
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard let name = parts.first else { return nil }
                return URLQueryItem(name: name, value: parts.count > 1 ? parts[1] : nil)
            }
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
