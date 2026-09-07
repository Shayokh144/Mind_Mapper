import XCTest
@testable import MindMapper

final class MixedQueryServiceTests: XCTestCase {
    func test_answer_runsMemoryAndGeneralThenMerges() async throws {
        let rag = MockRAGAnswerService()
        rag.result = RAGAnswer(
            text: "You mentioned a blue dress for the presentation.",
            representedSessionIds: ["s1", "s2"]
        )
        let llm = MockLLMService()
        llm.completeResultsQueue = [
            "Navy or charcoal also work well.", // general (.full)
            "You liked the blue dress; navy would also work.", // merge (.mini)
        ]

        let sut = MixedQueryService(ragAnswerService: rag, llmClient: llm)
        let answer = try await sut.answer(
            question: "What dress ideas did we discuss and suggest more?",
            sessionId: "s-query",
            userId: "u1"
        )

        XCTAssertEqual(rag.answerCallCount, 1)
        XCTAssertEqual(llm.completeCallCount, 2)
        XCTAssertEqual(llm.lastTier, .mini)
        XCTAssertEqual(llm.lastMaxTokens, 280)
        XCTAssertEqual(answer.text, "You liked the blue dress; navy would also work.")
        XCTAssertEqual(answer.representedSessionIds, ["s1", "s2"])

        let mergePrompt = llm.lastMessages?.last?.content ?? ""
        XCTAssertTrue(mergePrompt.contains("Ask short clarifying questions only"))
        XCTAssertTrue(mergePrompt.contains("Prior turns:"))
        XCTAssertTrue(mergePrompt.contains("budget-friendly ASEAN"))
        XCTAssertTrue(mergePrompt.contains("Copy full URLs"))

        // First complete was general knowledge at .full — verify via call order using queue empty.
        XCTAssertTrue(llm.completeResultsQueue.isEmpty)
    }

    func test_mixedQueryUseCase_delegatesToService() async throws {
        let rag = MockRAGAnswerService()
        let llm = MockLLMService()
        llm.completeResultsQueue = ["General tip", "Merged reply"]
        let useCase = MixedQueryUseCase(
            service: MixedQueryService(ragAnswerService: rag, llmClient: llm)
        )

        let answer = try await useCase.execute(
            question: "ideas?",
            sessionId: "s1",
            userId: "u1"
        )
        XCTAssertEqual(answer.text, "Merged reply")
    }
}
