import XCTest
@testable import MindMapper

final class MemoryExtractorTests: XCTestCase {
    func test_decode_stripsMarkdownFences() throws {
        let raw = """
        ```json
        {
          "clean_text": "Blue T-shirt is in the 3rd drawer",
          "entities": [
            { "type": "location", "value": "3rd drawer" },
            { "type": "category", "value": "clothing" }
          ],
          "supersedes_hint": null
        }
        ```
        """
        let result = try MemoryExtractor.decode(raw)
        XCTAssertEqual(result.cleanText, "Blue T-shirt is in the 3rd drawer")
        XCTAssertEqual(result.entities.count, 2)
        XCTAssertNil(result.supersedesHint)
    }

    func test_decode_invalidJSON_throwsLLMResponseInvalid() {
        XCTAssertThrowsError(try MemoryExtractor.decode("not-json")) { error in
            guard case AppError.llmResponseInvalid = error else {
                return XCTFail("Expected llmResponseInvalid, got \(error)")
            }
        }
    }

    func test_extract_usesMiniTier() async throws {
        let mock = MockLLMService()
        mock.completeResult = """
        {
          "clean_text": "Keys are on the shelf",
          "entities": [{ "type": "location", "value": "shelf" }],
          "supersedes_hint": null
        }
        """
        let sut = MemoryExtractor(llmClient: mock)
        let result = try await sut.extract(from: "I put my keys on the shelf")
        XCTAssertEqual(result.cleanText, "Keys are on the shelf")
        XCTAssertEqual(mock.lastTier, .mini)
        XCTAssertEqual(mock.lastMaxTokens, 300)
        XCTAssertEqual(mock.lastTemperature, 0)
    }
}
