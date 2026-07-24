import Foundation
import Combine
import Supabase

@MainActor
final class AppContainer: ObservableObject {
    let database: DatabaseManager
    let supabaseClient: SupabaseClient
    let authRepository: AuthRepositoryProtocol
    let authManager: AuthManager
    let networkReachability: NetworkReachabilityService

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
                auth: .init(
                    redirectToURL: AppConfig.authCallbackURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        let authRepository = AuthRepository(database: database)
        self.authRepository = authRepository
        self.authManager = AuthManager(
            client: supabaseClient,
            authRepository: authRepository
        )
        self.networkReachability = NetworkReachabilityService()
        LLMClient.configure(client: supabaseClient)
    }

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(
            authManager: authManager,
            networkReachability: networkReachability
        )
    }

    func makeForgotPasswordViewModel() -> ForgotPasswordViewModel {
        ForgotPasswordViewModel(
            authManager: authManager,
            networkReachability: networkReachability
        )
    }

    func makeSetNewPasswordViewModel() -> SetNewPasswordViewModel {
        SetNewPasswordViewModel(
            authManager: authManager,
            networkReachability: networkReachability
        )
    }

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(authManager: authManager)
    }
}
