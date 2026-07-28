import Foundation

/// Completions + embeddings for use cases. `LLMClient` conforms; tests use `MockLLMService`.
/// Opt out of module-wide MainActor default — callers are often `nonisolated` use cases.
nonisolated protocol LLMClientProtocol: AnyObject {
    func complete(
        tier: LLMModelTier,
        messages: [LLMMessage],
        maxTokens: Int,
        temperature: Double
    ) async throws -> String

    func embed(text: String, tier: LLMModelTier) async throws -> [Float]
}
