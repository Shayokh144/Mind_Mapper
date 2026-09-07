import XCTest
@testable import MindMapper

@MainActor
final class ChatViewModelTests: XCTestCase {
    private var classify: MockClassifyIntentUseCase!
    private var saveMemory: MockSaveMemoryUseCase!
    private var queryMemory: MockQueryMemoryUseCase!
    private var mixedQuery: MockMixedQueryUseCase!
    private var closeSession: MockCloseSessionUseCase!
    private var deleteSession: MockDeleteSessionUseCase!
    private var scopeGuard: MockScopeGuard!
    private var rateLimiter: MockRateLimiter!
    private var messages: MockMessageRepository!
    private var sessions: MockSessionRepository!
    private var llm: MockLLMService!
    private var notifications: MockLocalNotificationService!
    private var router: AppRouter!
    private var session: Session!
    private var sut: ChatViewModel!

    override func setUp() async throws {
        try await super.setUp()
        classify = MockClassifyIntentUseCase()
        saveMemory = MockSaveMemoryUseCase()
        queryMemory = MockQueryMemoryUseCase()
        mixedQuery = MockMixedQueryUseCase()
        closeSession = MockCloseSessionUseCase()
        deleteSession = MockDeleteSessionUseCase()
        scopeGuard = MockScopeGuard()
        rateLimiter = MockRateLimiter()
        messages = MockMessageRepository()
        sessions = MockSessionRepository()
        llm = MockLLMService()
        notifications = MockLocalNotificationService()
        router = AppRouter()
        session = Session(userId: "user-1", title: "Test")
        sessions.sessions = [session]
        sut = makeSUT()
    }

    override func tearDown() async throws {
        sut = nil
        router = nil
        session = nil
        classify = nil
        saveMemory = nil
        queryMemory = nil
        mixedQuery = nil
        closeSession = nil
        deleteSession = nil
        scopeGuard = nil
        rateLimiter = nil
        messages = nil
        sessions = nil
        llm = nil
        notifications = nil
        try await super.tearDown()
    }

    func test_sendMessage_storeIntent_callsSaveMemoryAndAppendsAck() async {
        classify.intent = .store
        saveMemory.result = SaveMemoryResult(
            ackText: "Got it — keys noted.",
            memoryId: "mem-keys",
            reminderProposal: nil
        )

        await sut.sendMessage("I put my keys on the table")

        XCTAssertEqual(saveMemory.executeCallCount, 1)
        XCTAssertEqual(queryMemory.executeCallCount, 0)
        XCTAssertEqual(mixedQuery.executeCallCount, 0)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.messages.count, 2)
        XCTAssertEqual(sut.messages[0].role, "user")
        XCTAssertEqual(sut.messages[1].content, "Got it — keys noted.")
        XCTAssertEqual(rateLimiter.recordAllowedCallCount, 1)
        // First turn — no prior context for STORE.
        XCTAssertEqual(saveMemory.lastConversationContext?.count, 0)
    }

    func test_sendMessage_planWithShopURL_isNotSanitiserBlocked() async {
        classify.intent = .store
        saveMemory.result = SaveMemoryResult(
            ackText: "Noted the Dhaka shopping stops.",
            memoryId: "mem-plan",
            reminderProposal: nil
        )

        await sut.sendMessage(
            """
            Need to visit vougue by prince outlet for Moushumy’s dress

            Also need to visit this online store for Sharee : https://www.facebook.com/share/r/1drnm7bd4K/?mibextid=wwXIfr
            """
        )

        XCTAssertEqual(scopeGuard.checkCallCount, 1)
        XCTAssertEqual(classify.executeCallCount, 1)
        XCTAssertEqual(saveMemory.executeCallCount, 1)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.messages.first?.role, "user")
        XCTAssertEqual(rateLimiter.recordBlockedCallCount, 0)
        XCTAssertEqual(rateLimiter.recordAllowedCallCount, 1)
    }

    func test_sendMessage_filePathNote_isNotSanitiserBlocked() async {
        classify.intent = .store
        saveMemory.result = SaveMemoryResult(
            ackText: "Noted the visa file location.",
            memoryId: "mem-visa",
            reminderProposal: nil
        )

        await sut.sendMessage("Visa PDF is at /Users/me/Documents/visa.pdf")

        XCTAssertEqual(scopeGuard.checkCallCount, 1)
        XCTAssertEqual(saveMemory.executeCallCount, 1)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(rateLimiter.recordBlockedCallCount, 0)
    }

    func test_sendMessage_planResearchQuestion_reachesMixedQuery() async {
        classify.intent = .mixed

        await sut.sendMessage("What is the best time to visit Bangladesh?")

        XCTAssertEqual(scopeGuard.checkCallCount, 1)
        XCTAssertEqual(mixedQuery.executeCallCount, 1)
        XCTAssertEqual(queryMemory.executeCallCount, 0)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(rateLimiter.recordBlockedCallCount, 0)
    }

    func test_sendMessage_projectPlan_isNotBlocked() async {
        classify.intent = .store
        saveMemory.result = SaveMemoryResult(
            ackText: "Noted the project ship date.",
            memoryId: "mem-project",
            reminderProposal: nil
        )

        await sut.sendMessage("We decided the project ships in October")

        XCTAssertEqual(scopeGuard.checkCallCount, 1)
        XCTAssertEqual(saveMemory.executeCallCount, 1)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(rateLimiter.recordBlockedCallCount, 0)
    }

    func test_sendMessage_projectRecall_reachesQueryOrMixed() async {
        classify.intent = .query
        queryMemory.result = RAGAnswer(
            text: "You decided the project ships in October.",
            representedSessionIds: ["s1"]
        )

        await sut.sendMessage("What did we decide about the project deadline?")

        XCTAssertEqual(scopeGuard.checkCallCount, 1)
        XCTAssertEqual(queryMemory.executeCallCount, 1)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(rateLimiter.recordBlockedCallCount, 0)
    }

    func test_sendMessage_tryAgainFindTheLink_reachesQuery() async {
        classify.intent = .query
        queryMemory.result = RAGAnswer(
            text: "https://www.facebook.com/share/r/1drnm7bd4K/?mibextid=wwXIfr",
            representedSessionIds: ["s1"]
        )

        await sut.sendMessage("Try again and check if you can find the link")

        XCTAssertEqual(scopeGuard.checkCallCount, 1)
        XCTAssertEqual(queryMemory.executeCallCount, 1)
        XCTAssertEqual(rateLimiter.recordBlockedCallCount, 0)
        XCTAssertNil(sut.errorMessage)
    }

    func test_sendMessage_storeWithHistory_passesRollingContext() async throws {
        classify.intent = .store
        messages.messages = [
            Message(sessionId: session.id, role: "user", content: "I kept my passport in the 3rd drawer"),
            Message(sessionId: session.id, role: "assistant", content: "Got it."),
        ]
        await sut.loadSession()

        await sut.sendMessage("It is inside a blue colored file.")

        XCTAssertEqual(saveMemory.executeCallCount, 1)
        let context = try XCTUnwrap(saveMemory.lastConversationContext)
        XCTAssertEqual(context.count, 2)
        XCTAssertEqual(context[0].content, "I kept my passport in the 3rd drawer")
        XCTAssertEqual(context[1].content, "Got it.")
        XCTAssertEqual(classify.lastConversationContext?.count, 2)
        XCTAssertEqual(scopeGuard.lastConversationContext?.count, 2)
    }

    func test_sendMessage_chatWithHistory_includesPriorTurnsInLLMPayload() async throws {
        classify.intent = .chat
        llm.completeResult = "You're welcome!"
        messages.messages = [
            Message(sessionId: session.id, role: "user", content: "Hello"),
            Message(sessionId: session.id, role: "assistant", content: "Hi there"),
        ]
        await sut.loadSession()

        await sut.sendMessage("Thanks!")

        XCTAssertEqual(llm.completeCallCount, 1)
        let payload = try XCTUnwrap(llm.lastMessages)
        // system + 2 history + current
        XCTAssertEqual(payload.count, 4)
        XCTAssertEqual(payload[0].role, "system")
        XCTAssertEqual(payload[1].content, "Hello")
        XCTAssertEqual(payload[2].content, "Hi there")
        XCTAssertEqual(payload[3].content, "Thanks!")
    }

    func test_sessionAtMessageLimit_blocksSendAndSkipsUseCases() async {
        classify.intent = .store
        let limit = ChatLimits.maxMessagesPerSession - 1
        messages.messages = (0..<limit).map { index in
            Message(
                sessionId: session.id,
                // End on assistant so loadSession does not prefer incomplete-turn copy.
                role: index.isMultiple(of: 2) ? "assistant" : "user",
                content: "m\(index)"
            )
        }
        await sut.loadSession()

        XCTAssertTrue(sut.isSessionAtMessageLimit)
        XCTAssertFalse(sut.canSend)
        XCTAssertEqual(sut.errorMessage, L10n.Chat.sessionFull)

        sut.inputText = "One more fact"
        await sut.sendMessage()

        XCTAssertEqual(saveMemory.executeCallCount, 0)
        XCTAssertEqual(classify.executeCallCount, 0)
        XCTAssertEqual(sut.messages.count, limit)
        XCTAssertEqual(sut.errorMessage, L10n.Chat.sessionFull)
    }

    func test_sendMessage_queryIntent_callsQueryMemoryAndSetsSessionCount() async {
        classify.intent = .query
        queryMemory.result = RAGAnswer(
            text: "Keys are on the table.",
            representedSessionIds: ["a", "b"]
        )

        await sut.sendMessage("Where are my keys?")

        XCTAssertEqual(queryMemory.executeCallCount, 1)
        XCTAssertEqual(saveMemory.executeCallCount, 0)
        XCTAssertEqual(sut.lastAnswerSessionCount, 2)
        XCTAssertEqual(sut.messages.last?.content, "Keys are on the table.")
        XCTAssertFalse(sut.isLoading)
    }

    func test_sendMessage_mixedIntent_callsMixedQuery() async {
        classify.intent = .mixed

        await sut.sendMessage("What dress ideas did we discuss and suggest more?")

        XCTAssertEqual(mixedQuery.executeCallCount, 1)
        XCTAssertEqual(queryMemory.executeCallCount, 0)
        XCTAssertEqual(sut.lastAnswerSessionCount, 2)
        XCTAssertEqual(sut.messages.last?.content, mixedQuery.result.text)
        XCTAssertFalse(sut.isLoading)
    }

    func test_sendMessage_birthdayGiftSuggestion_reachesMixedQuery() async {
        classify.intent = .mixed

        await sut.sendMessage("Suggests me some good birthday gift")

        XCTAssertEqual(scopeGuard.checkCallCount, 1)
        XCTAssertEqual(mixedQuery.executeCallCount, 1)
        XCTAssertEqual(queryMemory.executeCallCount, 0)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(rateLimiter.recordBlockedCallCount, 0)
    }

    func test_sendMessage_scopeBlocked_showsWarningBubbleAndSkipsUseCases() async {
        scopeGuard.result = .outOfScope(L10n.Guard.scopeBlocked)
        classify.intent = .store

        // Passes InputSanitiser ("debug this" is a code signal) but fails ScopeGuard.
        await sut.sendMessage("What is the capital of France?")

        XCTAssertEqual(scopeGuard.checkCallCount, 1)
        XCTAssertEqual(classify.executeCallCount, 0)
        XCTAssertEqual(saveMemory.executeCallCount, 0)
        XCTAssertEqual(queryMemory.executeCallCount, 0)
        XCTAssertEqual(mixedQuery.executeCallCount, 0)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.messages.last?.role, "assistant")
        XCTAssertEqual(sut.messages.last?.content, L10n.Guard.scopeBlocked)
        XCTAssertEqual(sut.messages.last?.isWarning, true)
        XCTAssertTrue(sut.canRetryLastTurn)
        XCTAssertEqual(sut.lastFailedUserMessage?.content, "What is the capital of France?")
        XCTAssertEqual(rateLimiter.recordBlockedCallCount, 1)
        XCTAssertFalse(sut.isLoading)
    }

    func test_retryLastTurn_afterScopeBlock_removesWarningAndResends() async {
        scopeGuard.result = .outOfScope(L10n.Guard.scopeBlocked)
        await sut.sendMessage("What is the capital of France?")
        XCTAssertTrue(sut.canRetryLastTurn)

        scopeGuard.result = .inScope
        classify.intent = .chat
        llm.completeResult = "Happy to help with your plans."

        await sut.retryLastTurn()

        XCTAssertEqual(classify.executeCallCount, 1)
        XCTAssertEqual(sut.messages.count, 2)
        XCTAssertEqual(sut.messages[0].role, "user")
        XCTAssertEqual(sut.messages[1].content, "Happy to help with your plans.")
        XCTAssertEqual(sut.messages[1].isWarning, false)
        XCTAssertFalse(sut.canRetryLastTurn)
        XCTAssertFalse(messages.messages.contains { $0.content == L10n.Guard.scopeBlocked })
    }

    func test_editAndRetry_afterScopeBlock_updatesUserMessage() async {
        scopeGuard.result = .outOfScope(L10n.Guard.scopeBlocked)
        await sut.sendMessage("What is the capital of France?")

        sut.beginEditFailedTurn()
        XCTAssertTrue(sut.isEditingFailedTurn)
        XCTAssertEqual(sut.inputText, "What is the capital of France?")
        XCTAssertFalse(sut.canRetryLastTurn)

        scopeGuard.result = .inScope
        classify.intent = .store
        saveMemory.result = SaveMemoryResult(
            ackText: "Noted the Dhaka outlet.",
            memoryId: "mem-outlet",
            reminderProposal: nil
        )
        sut.inputText = "Need to visit the Dhaka outlet for a dress"
        await sut.sendMessage()

        XCTAssertFalse(sut.isEditingFailedTurn)
        XCTAssertEqual(sut.inputText, "")
        XCTAssertEqual(sut.messages.count, 2)
        XCTAssertEqual(sut.messages[0].content, "Need to visit the Dhaka outlet for a dress")
        XCTAssertEqual(sut.messages[1].content, "Noted the Dhaka outlet.")
        XCTAssertFalse(sut.canRetryLastTurn)
    }

    func test_sendMessage_sanitiserBlocksCode_keepsComposerText() async {
        let blocked = "```swift\nfunc foo() {}\n```"
        sut.inputText = blocked
        await sut.sendMessage()

        XCTAssertEqual(scopeGuard.checkCallCount, 0)
        XCTAssertEqual(classify.executeCallCount, 0)
        XCTAssertEqual(saveMemory.executeCallCount, 0)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertEqual(sut.inputText, blocked)
        XCTAssertEqual(rateLimiter.recordBlockedCallCount, 1)
        XCTAssertFalse(sut.isLoading)
    }

    func test_sendMessage_rateLimited_keepsComposerText() async {
        rateLimiter.checkResult = .throttled("Please wait 60 seconds before sending another message.")
        sut.inputText = "I put my keys on the table"

        await sut.sendMessage()

        XCTAssertEqual(scopeGuard.checkCallCount, 0)
        XCTAssertEqual(classify.executeCallCount, 0)
        XCTAssertEqual(saveMemory.executeCallCount, 0)
        XCTAssertEqual(
            sut.errorMessage,
            "Please wait 60 seconds before sending another message."
        )
        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertEqual(sut.inputText, "I put my keys on the table")
        XCTAssertFalse(sut.isLoading)
    }

    func test_sendMessage_pipelineError_setsAppErrorMessageAndClearsLoading() async {
        classify.intent = .query
        queryMemory.error = AppError.llmCallFailed(
            underlying: NSError(domain: "test", code: 1)
        )

        await sut.sendMessage("Where are my keys?")

        XCTAssertEqual(
            sut.errorMessage,
            "Couldn't reach the AI. Check your connection and try again."
        )
        XCTAssertFalse(sut.isLoading)
        // User message was saved before the failure
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages[0].role, "user")
        XCTAssertTrue(sut.canRetryLastTurn)
    }

    func test_loadSession_populatesMessages() async {
        messages.messages = [
            Message(sessionId: session.id, role: "user", content: "Hi"),
            Message(sessionId: session.id, role: "assistant", content: "Hello"),
        ]

        await sut.loadSession()

        XCTAssertEqual(sut.messages.count, 2)
        XCTAssertEqual(sut.currentSession?.id, session.id)
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadSession_trailingScopeWarning_isRetryable() async {
        messages.messages = [
            Message(
                sessionId: session.id,
                role: "user",
                content: "What is the capital of France?"
            ),
            Message(
                sessionId: session.id,
                role: "assistant",
                content: L10n.Guard.scopeBlocked
            ),
        ]

        await sut.loadSession()

        XCTAssertEqual(sut.messages.last?.isWarning, true)
        XCTAssertTrue(sut.canRetryLastTurn)
        XCTAssertEqual(sut.lastFailedUserMessage?.content, "What is the capital of France?")
    }

    func test_startNewSession_resetsMessages() async throws {
        messages.messages = [
            Message(sessionId: session.id, role: "user", content: "Old"),
        ]
        await sut.loadSession()
        XCTAssertEqual(sut.messages.count, 1)

        let created = try await sut.startNewSession(userId: "user-1")

        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertEqual(sut.currentSession?.id, created.id)
        XCTAssertEqual(sessions.sessions.count, 2)
    }

    func test_closeSession_afterMessage_callsUseCaseOnce() async {
        classify.intent = .chat
        llm.completeResult = "Hello!"

        await sut.sendMessage("Hi there")
        await sut.closeSession()
        await sut.closeSession()

        XCTAssertEqual(closeSession.executeCallCount, 1)
        XCTAssertEqual(closeSession.lastSessionId, session.id)
    }

    func test_closeSession_withoutActivity_doesNotCallUseCase() async {
        await sut.closeSession()
        XCTAssertEqual(closeSession.executeCallCount, 0)
    }

    func test_closeSession_whileLoading_doesNotCallUseCase() async {
        classify.intent = .chat
        llm.completeResult = "Hello!"
        // Hold the pipeline in scope check so isLoading stays true.
        scopeGuard.checkDelayNanoseconds = 200_000_000

        let sendTask = Task { await sut.sendMessage("Hi there") }
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(sut.isLoading)
        await sut.closeSession()
        XCTAssertEqual(closeSession.executeCallCount, 0)
        await sendTask.value
        XCTAssertFalse(sut.isLoading)
    }

    func test_inactivity_triggersCloseSession() async {
        sut = makeSUT(inactivityInterval: 0.05)
        classify.intent = .chat
        llm.completeResult = "Hello!"

        await sut.sendMessage("Hi there")
        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(closeSession.executeCallCount, 1)
    }


    func test_stopGenerating_cancelsPipelineAndPrefillsEdit() async {
        classify.intent = .chat
        llm.completeResult = "Should not appear"
        scopeGuard.checkDelayNanoseconds = 300_000_000

        let sendTask = Task { await sut.sendMessage("Hi there") }
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertTrue(sut.isLoading)

        sut.stopGenerating()

        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(sut.isEditingFailedTurn)
        XCTAssertEqual(sut.inputText, "Hi there")
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertTrue(sut.messages.last?.isUser == true)

        await sendTask.value
        // Late pipeline must not append an assistant bubble.
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertFalse(sut.isLoading)
    }

    func test_storeWithReminderProposal_setsPendingOffer_doesNotSchedule() async {
        classify.intent = .store
        saveMemory.result = SaveMemoryResult(
            ackText: "Got it — medicine noted.",
            memoryId: "mem-med",
            reminderProposal: ReminderProposal(
                shouldSetNotification: true,
                title: "Take medicine",
                description: "Time to take your medicine",
                fireAt: Date().addingTimeInterval(3_600),
                recurrence: .once
            )
        )

        await sut.sendMessage("I need to eat medicine tomorrow at 10 PM")

        XCTAssertEqual(sut.pendingReminderOffer?.memoryId, "mem-med")
        XCTAssertEqual(sut.pendingReminderOffer?.title, "Take medicine")
        XCTAssertTrue(notifications.scheduled.isEmpty)
        XCTAssertEqual(notifications.requestCallCount, 0)
    }

    func test_acceptReminderOffer_authorized_presentsSheetWithoutScheduling() async {
        classify.intent = .store
        saveMemory.result = SaveMemoryResult(
            ackText: "Noted.",
            memoryId: "mem-hr",
            reminderProposal: ReminderProposal(
                shouldSetNotification: true,
                title: "Ask HR",
                description: nil,
                fireAt: nil,
                recurrence: nil
            )
        )
        notifications.status = .authorized
        await sut.sendMessage("I need to ask office HR about leave")

        await sut.acceptReminderOffer()

        XCTAssertTrue(notifications.scheduled.isEmpty)
        if case let .reminderEditor(draft) = router.presentedSheet {
            XCTAssertEqual(draft.memoryId, "mem-hr")
            XCTAssertFalse(draft.didSelectDate)
        } else {
            XCTFail("Expected reminder editor sheet")
        }
    }

    // MARK: - Helpers

    private func makeSUT(inactivityInterval: TimeInterval = 120) -> ChatViewModel {
        ChatViewModel(
            sessionId: session.id,
            userId: "user-1",
            dependencies: ChatDependencies(
                rateLimiter: rateLimiter,
                scopeGuard: scopeGuard,
                classifyIntentUseCase: classify,
                saveMemoryUseCase: saveMemory,
                queryMemoryUseCase: queryMemory,
                mixedQueryUseCase: mixedQuery,
                closeSessionUseCase: closeSession,
                llmClient: llm,
                messageRepository: messages,
                sessionRepository: sessions,
                notificationService: notifications
            ),
            deleteSessionUseCase: deleteSession,
            router: router,
            inactivityInterval: inactivityInterval
        )
    }
}
