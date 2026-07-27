import Foundation
@testable import MindMapper

nonisolated final class MockMemoryExtractor: MemoryExtractorProtocol, @unchecked Sendable {
    var result: ExtractionResult
    var error: Error?

    init(result: ExtractionResult) {
        self.result = result
    }

    func extract(from rawText: String) async throws -> ExtractionResult {
        if let error { throw error }
        return result
    }
}
