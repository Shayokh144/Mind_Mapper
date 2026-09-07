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
        XCTAssertEqual(mock.lastMaxTokens, 768)
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

    func test_decode_reminderProposal_nullDatetime() throws {
        let raw = """
        {
          "clean_text": "User needs to ask office HR about leave policy",
          "entities": [{ "type": "topic_id", "value": "hr_leave" }],
          "supersedes_hint": null,
          "should_set_notification": true,
          "notification_title": "Ask HR about leave",
          "notification_description": null,
          "notification_datetime": null,
          "notification_recurrence": null
        }
        """
        let result = try MemoryExtractor.decode(raw)
        XCTAssertTrue(result.shouldSetNotification)
        XCTAssertEqual(result.notificationTitle, "Ask HR about leave")
        XCTAssertNil(result.notificationDatetime)
        XCTAssertNil(result.notificationRecurrence)
        XCTAssertEqual(result.reminderProposal?.shouldSetNotification, true)
        XCTAssertNil(result.reminderProposal?.fireAt)
    }

    func test_decode_reminderProposal_filledDatetime() throws {
        let raw = """
        {
          "clean_text": "User needs to take medicine tomorrow at 10 PM",
          "entities": [],
          "should_set_notification": true,
          "notification_title": "Take medicine",
          "notification_description": "Time to take your medicine",
          "notification_datetime": "2026-08-15T22:00:00+07:00",
          "notification_recurrence": "once"
        }
        """
        let result = try MemoryExtractor.decode(raw)
        XCTAssertEqual(result.notificationRecurrence, .once)
        XCTAssertNotNil(result.notificationDatetime)
        XCTAssertEqual(result.reminderProposal?.title, "Take medicine")
    }

    func test_decode_missingReminderFields_defaultsFalse() throws {
        let raw = """
        {"clean_text": "Keys are on the shelf", "entities": [], "supersedes_hint": null}
        """
        let result = try MemoryExtractor.decode(raw)
        XCTAssertFalse(result.shouldSetNotification)
        XCTAssertNil(result.reminderProposal)
    }
}
