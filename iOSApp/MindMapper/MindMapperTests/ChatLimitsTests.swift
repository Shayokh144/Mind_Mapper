import XCTest
@testable import MindMapper

final class ChatLimitsTests: XCTestCase {
    func test_rollingContext_truncatesToLastN_preservesOrder() {
        let messages = (1...20).map { index in
            Message(sessionId: "s", role: index.isMultiple(of: 2) ? "assistant" : "user", content: "m\(index)")
        }

        let rolling = ChatLimits.rollingContext(from: messages, limit: 5)

        XCTAssertEqual(rolling.map(\.content), ["m16", "m17", "m18", "m19", "m20"])
        XCTAssertEqual(rolling.first?.content, "m16")
    }

    func test_rollingContext_shortList_returnsAll() {
        let messages = [
            Message(sessionId: "s", role: "user", content: "a"),
            Message(sessionId: "s", role: "assistant", content: "b"),
        ]
        XCTAssertEqual(ChatLimits.rollingContext(from: messages, limit: 12).count, 2)
    }

    func test_isAtMessageLimit_needsRoomForUserAndAssistant() {
        XCTAssertFalse(ChatLimits.isAtMessageLimit(currentCount: 38))
        XCTAssertTrue(ChatLimits.isAtMessageLimit(currentCount: 39))
        XCTAssertTrue(ChatLimits.isAtMessageLimit(currentCount: 40))
    }

    func test_llmMessagesExcludingTrailingUser_dropsMatchingTail() {
        let messages = [
            Message(sessionId: "s", role: "user", content: "earlier"),
            Message(sessionId: "s", role: "assistant", content: "ok"),
            Message(sessionId: "s", role: "user", content: "current"),
        ]
        let llm = ChatLimits.llmMessagesExcludingTrailingUser(from: messages, currentText: "current")
        XCTAssertEqual(llm.map(\.content), ["earlier", "ok"])
    }

    func test_usageFraction_scalesWithCount() {
        XCTAssertEqual(ChatLimits.usageFraction(currentCount: 0), 0, accuracy: 0.001)
        XCTAssertEqual(ChatLimits.usageFraction(currentCount: 20), 0.5, accuracy: 0.001)
        XCTAssertEqual(ChatLimits.usageFraction(currentCount: 40), 1, accuracy: 0.001)
        XCTAssertEqual(ChatLimits.usageFraction(currentCount: 50), 1, accuracy: 0.001)
    }

    func test_maxCharacters_aliasesInputSanitiser() {
        XCTAssertEqual(ChatLimits.maxCharactersPerMessage, InputSanitiser.maxCharacters)
        XCTAssertEqual(ChatLimits.maxMessagesPerSession, 40)
        XCTAssertEqual(ChatLimits.rollingContextMessageCount, 12)
    }
}
