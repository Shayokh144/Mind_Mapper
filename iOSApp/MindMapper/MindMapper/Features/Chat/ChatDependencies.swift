import Foundation

/// Bundles ChatViewModel collaborators so init stays under the DI parameter limit.
struct ChatDependencies {
    let rateLimiter: RateLimiterProtocol
    let scopeGuard: ScopeGuardProtocol
    let classifyIntentUseCase: ClassifyIntentUseCaseProtocol
    let saveMemoryUseCase: SaveMemoryUseCaseProtocol
    let queryMemoryUseCase: QueryMemoryUseCaseProtocol
    let mixedQueryUseCase: MixedQueryUseCaseProtocol
    let closeSessionUseCase: CloseSessionUseCaseProtocol
    let llmClient: LLMClientProtocol
    let messageRepository: MessageRepositoryProtocol
    let sessionRepository: SessionRepositoryProtocol
    let notificationService: LocalNotificationServiceProtocol
}
