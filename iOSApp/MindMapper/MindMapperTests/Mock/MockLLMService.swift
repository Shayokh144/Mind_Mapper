import Foundation
@testable import MindMapper

final class MockLLMService: LLMClientProtocol {
    var completeResult: String = "CHAT"
    var completeError: Error?
    private(set) var lastTier: LLMModelTier?
    private(set) var lastMessages: [LLMMessage]?
    private(set) var lastMaxTokens: Int?
    private(set) var lastTemperature: Double?
    private(set) var completeCallCount = 0

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
        return completeResult
    }
}
