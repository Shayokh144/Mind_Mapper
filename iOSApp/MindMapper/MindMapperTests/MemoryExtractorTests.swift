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
        XCTAssertEqual(mock.lastMaxTokens, 1_024)
        XCTAssertEqual(mock.lastTemperature, 0)
    }

    func test_decode_extractsJSONObjectFromPreamble() throws {
        let raw = """
        Here you go:
        {"clean_text": "Water bill is on the expense list", "entities": [{"type": "category", "value": "expenses"}], "supersedes_hint": null}
        """
        let result = try MemoryExtractor.decode(raw)
        XCTAssertEqual(result.cleanText, "Water bill is on the expense list")
        XCTAssertEqual(result.entities.count, 1)
    }

    func test_extract_retriesOnceOnInvalidJSON() async throws {
        let mock = MockLLMService()
        mock.completeResultsQueue = [
            "{", // truncated → decode fails
            """
            {"clean_text": "Water bill is on the expense list", "entities": [], "supersedes_hint": null}
            """,
        ]
        let sut = MemoryExtractor(llmClient: mock)
        let result = try await sut.extract(from: "Need to add water bill in the expense list.")
        XCTAssertEqual(result.cleanText, "Water bill is on the expense list")
        XCTAssertEqual(mock.completeCallCount, 2)
    }
}
