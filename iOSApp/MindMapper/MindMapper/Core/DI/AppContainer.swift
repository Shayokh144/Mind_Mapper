import Foundation
import Combine
import Supabase

@MainActor
final class AppContainer: ObservableObject {
    let database: DatabaseManager
    let supabaseClient: SupabaseClient
    let authRepository: AuthRepositoryProtocol
    let authManager: AuthManager

    /// Returns `nil` if Supabase URL config is invalid.
    static func make(database: DatabaseManager) -> AppContainer? {
        guard let supabaseURL = AppConfig.supabaseURL else {
            return nil
        }
        return AppContainer(database: database, supabaseURL: supabaseURL)
    }

    private init(database: DatabaseManager, supabaseURL: URL) {
        self.database = database
        self.supabaseClient = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
        let authRepository = AuthRepository(database: database)
        self.authRepository = authRepository
        self.authManager = AuthManager(
            client: supabaseClient,
            authRepository: authRepository
        )
    }

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(authManager: authManager)
    }

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(authManager: authManager)
    }
}
