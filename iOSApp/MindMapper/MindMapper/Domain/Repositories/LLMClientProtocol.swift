import Foundation

/// Completions + embeddings for use cases. `LLMClient` conforms; tests use `MockLLMService`.
protocol LLMClientProtocol: AnyObject {
    func complete(
        tier: LLMModelTier,
        messages: [LLMMessage],
        maxTokens: Int,
        temperature: Double
    ) async throws -> String
}
