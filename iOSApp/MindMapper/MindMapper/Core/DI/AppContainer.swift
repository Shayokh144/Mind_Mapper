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
    let scopeGuard: ScopeGuardProtocol
    let rateLimiter: RateLimiterProtocol
    let memoryRepository: MemoryRepositoryProtocol
    let vectorRepository: VectorRepositoryProtocol
    let sessionRepository: SessionRepositoryProtocol
    let messageRepository: MessageRepositoryProtocol

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
        self.scopeGuard = ScopeGuard(llmClient: LLMClient.shared)
        self.rateLimiter = RateLimiter()
        self.memoryRepository = MemoryRepository(database: database)
        self.vectorRepository = VectorRepository(database: database)
        self.sessionRepository = SessionRepository(database: database)
        self.messageRepository = MessageRepository(database: database)
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

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(authManager: authManager)
    }

    /// Requires a signed-in user. Returns `nil` when unauthenticated.
    func makeSessionListViewModel(router: AppRouter) -> SessionListViewModel? {
        guard let userId = authManager.currentUser?.id else {
            AppLogger.error("makeSessionListViewModel called without an authenticated user")
            return nil
        }
        return SessionListViewModel(
            userId: userId,
            sessionRepository: sessionRepository,
            router: router
        )
    }

    func makeClassifyIntentUseCase() -> ClassifyIntentUseCaseProtocol {
        ClassifyIntentUseCase(llmClient: LLMClient.shared)
    }

    func makeSaveMemoryUseCase() -> SaveMemoryUseCaseProtocol {
        SaveMemoryUseCase(
            memoryRepository: memoryRepository,
            vectorRepository: vectorRepository,
            memoryExtractor: MemoryExtractor(llmClient: LLMClient.shared),
            llmClient: LLMClient.shared
        )
    }

    func makeRAGRetriever() -> RAGRetriever {
        RAGRetriever(
            llmClient: LLMClient.shared,
            vectorStore: VectorStore(database: database),
            database: database
        )
    }

    func makeRAGAnswerService() -> RAGAnswerServiceProtocol {
        RAGAnswerService(
            retriever: makeRAGRetriever(),
            llmClient: LLMClient.shared,
            database: database
        )
    }

    func makeQueryMemoryUseCase() -> QueryMemoryUseCaseProtocol {
        QueryMemoryUseCase(answerService: makeRAGAnswerService())
    }

    func makeMixedQueryUseCase() -> MixedQueryUseCaseProtocol {
        MixedQueryUseCase(
            service: MixedQueryService(
                ragAnswerService: makeRAGAnswerService(),
                llmClient: LLMClient.shared
            )
        )
    }

    func makeCloseSessionUseCase() -> CloseSessionUseCaseProtocol {
        CloseSessionUseCase(
            messageRepository: messageRepository,
            sessionRepository: sessionRepository,
            memoryRepository: memoryRepository,
            vectorRepository: vectorRepository,
            llmClient: LLMClient.shared
        )
    }

    func makeChatDependencies() -> ChatDependencies {
        ChatDependencies(
            rateLimiter: rateLimiter,
            scopeGuard: scopeGuard,
            classifyIntentUseCase: makeClassifyIntentUseCase(),
            saveMemoryUseCase: makeSaveMemoryUseCase(),
            queryMemoryUseCase: makeQueryMemoryUseCase(),
            mixedQueryUseCase: makeMixedQueryUseCase(),
            closeSessionUseCase: makeCloseSessionUseCase(),
            llmClient: LLMClient.shared,
            messageRepository: messageRepository,
            sessionRepository: sessionRepository
        )
    }

    /// Requires a signed-in user. Returns `nil` when unauthenticated.
    func makeChatViewModel(sessionId: String, router: AppRouter) -> ChatViewModel? {
        guard let userId = authManager.currentUser?.id else {
            AppLogger.error("makeChatViewModel called without an authenticated user")
            return nil
        }
        return ChatViewModel(
            sessionId: sessionId,
            userId: userId,
            dependencies: makeChatDependencies(),
            router: router
        )
    }
}
