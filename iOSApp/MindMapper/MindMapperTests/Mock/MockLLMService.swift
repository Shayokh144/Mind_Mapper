import Foundation
@testable import MindMapper

nonisolated final class MockLLMService: LLMClientProtocol, @unchecked Sendable {
    var completeResult: String = "CHAT"
    /// FIFO queue used when multiple `complete` calls need different payloads.
    var completeResultsQueue: [String] = []
    var completeError: Error?
    var embedResult: [Float] = Array(repeating: 0.1, count: 1_536)
    /// Optional per-call embeddings (FIFO). Falls back to `embedResult`.
    var embedResultsQueue: [[Float]] = []
    var embedError: Error?

    private(set) var lastTier: LLMModelTier?
    private(set) var lastMessages: [LLMMessage]?
    private(set) var lastMaxTokens: Int?
    private(set) var lastTemperature: Double?
    private(set) var completeCallCount = 0
    private(set) var embedCallCount = 0
    private(set) var lastEmbedText: String?

    func complete(
        tier: LLMModelTier,
        messages: [LLMMessage],
        maxTokens: Int,
        temperature: Double
    ) async throws -> String {
        completeCallCount += 1
        lastTier = tier
        lastMessages = messages
        lastMaxTokens = maxTokens
        lastTemperature = temperature
        if let completeError {
            throw completeError
        }
        if !completeResultsQueue.isEmpty {
            return completeResultsQueue.removeFirst()
        }
        return completeResult
    }

    func embed(text: String, tier: LLMModelTier) async throws -> [Float] {
        embedCallCount += 1
        lastEmbedText = text
        if let embedError {
            throw embedError
        }
        if !embedResultsQueue.isEmpty {
            return embedResultsQueue.removeFirst()
        }
        return embedResult
    }
}
