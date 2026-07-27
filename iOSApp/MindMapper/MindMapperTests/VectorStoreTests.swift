import XCTest
@testable import MindMapper

final class VectorStoreTests: XCTestCase {
    func test_cosineSimilarity_identicalVectors_isOne() {
        let vector: [Float] = [1, 0, 0]
        XCTAssertEqual(VectorStore.cosineSimilarity(vector, vector), 1, accuracy: 0.0001)
    }

    func test_cosineSimilarity_orthogonalVectors_isZero() {
        let a: [Float] = [1, 0]
        let b: [Float] = [0, 1]
        XCTAssertEqual(VectorStore.cosineSimilarity(a, b), 0, accuracy: 0.0001)
    }

    func test_cosineSimilarity_mismatchedLength_isZero() {
        XCTAssertEqual(VectorStore.cosineSimilarity([1, 2], [1]), 0)
    }
}
