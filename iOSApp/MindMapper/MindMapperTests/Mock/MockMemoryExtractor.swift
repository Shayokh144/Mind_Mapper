import Foundation
@testable import MindMapper

nonisolated final class MockMemoryExtractor: MemoryExtractorProtocol, @unchecked Sendable {
    var result: ExtractionResult
    var error: Error?
    private(set) var lastRawText: String?
    private(set) var lastConversationContext: [LLMMessage]?
    private(set) var extractCallCount = 0

    init(result: ExtractionResult) {
        self.result = result
    }

    func extract(
        from rawText: String,
        conversationContext: [LLMMessage]
    ) async throws -> ExtractionResult {
        extractCallCount += 1
        lastRawText = rawText
        lastConversationContext = conversationContext
        if let error { throw error }
        return result
    }
}
