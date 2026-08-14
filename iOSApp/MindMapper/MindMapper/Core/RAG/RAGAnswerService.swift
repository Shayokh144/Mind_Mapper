import Foundation
import GRDB

/// Grounded QUERY answer + session IDs for the cross-conversation badge.
nonisolated struct RAGAnswer: Equatable, Sendable {
    let text: String
    let representedSessionIds: [String]
}

protocol RAGAnswerServiceProtocol {
    func answer(
        question: String,
        sessionId: String,
        userId: String
    ) async throws -> RAGAnswer
}

/// Stages 1–4 of the RAG query pipeline: retrieve → filter → temporal resolve → LLM synthesis.
nonisolated struct RAGAnswerService: RAGAnswerServiceProtocol, @unchecked Sendable {
    private let retriever: RAGRetriever
    private let llmClient: LLMClientProtocol
    private let database: DatabaseManager

    init(
        retriever: RAGRetriever,
        llmClient: LLMClientProtocol,
        database: DatabaseManager
    ) {
        self.retriever = retriever
        self.llmClient = llmClient
        self.database = database
    }

    func answer(
        question: String,
        sessionId: String,
        userId: String
    ) async throws -> RAGAnswer {
        let raw = try await retriever.retrieve(question: question, userId: userId)
        let confident = RAGRetriever.filterConfident(raw)
        let sessionIds = RetrievedChunk.representedSessionIds(in: confident)

        if confident.isEmpty {
            let text = try await noMemoryReply(question: question)
            return RAGAnswer(text: text, representedSessionIds: [])
        }

        let resolved = RAGRetriever.resolveTemporalOrder(confident)
        let recentMessages = try await loadRecentMessages(sessionId: sessionId)
        let text = try await synthesise(
            question: question,
            memories: resolved,
            recentMessages: recentMessages
        )
        return RAGAnswer(text: text, representedSessionIds: sessionIds)
    }

    // MARK: - Private

    private func noMemoryReply(question: String) async throws -> String {
        let reply = try await llmClient.complete(
            tier: .mini,
            messages: [
                LLMMessage(
                    role: "system",
                    content: """
                    You are a personal memory assistant. You have no stored information about this topic. \
                    Say briefly and warmly that you don't have anything stored about that. Do not invent facts.
                    """
                ),
                LLMMessage(role: "user", content: question),
            ],
            maxTokens: 150,
            temperature: 0.5
        )
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.llmResponseInvalid }
        return trimmed
    }

    private func loadRecentMessages(sessionId: String) async throws -> [Message] {
        do {
            let fetched = try await database.dbQueue.read { db in
                try MessageRecord
                    .filter(Column("session_id") == sessionId)
                    .order(Column("created_at").desc)
                    .limit(ChatLimits.rollingContextMessageCount)
                    .fetchAll(db)
                    .reversed()
                    .map(\.domainModel)
            }
            return ChatLimits.rollingContext(from: Array(fetched))
        } catch {
            AppLogger.error("Failed to load recent messages for session \(sessionId)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }

    private func synthesise(
        question: String,
        memories: [RetrievedChunk],
        recentMessages: [Message]
    ) async throws -> String {
        let memoriesText = Self.formatMemories(memories)
        var messages: [LLMMessage] = [
            LLMMessage(role: "system", content: Self.systemPrompt),
            LLMMessage(
                role: "user",
                content: """
                Retrieved memories (chronological, oldest first):
                \(memoriesText)
                """
            ),
        ]

        let history = ChatLimits.llmMessagesExcludingTrailingUser(
            from: recentMessages,
            currentText: question
        )
        messages.append(contentsOf: history)
        messages.append(LLMMessage(role: "user", content: question))

        let reply = try await llmClient.complete(
            tier: .mini,
            messages: messages,
            maxTokens: 400,
            temperature: 0.4
        )
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.llmResponseInvalid }
        return trimmed
    }

    static let systemPrompt = """
    You are a personal memory assistant. Answer ONLY from the provided memories.
    Do not guess or add information not in the memories.

    If multiple memories show the same topic evolving over time:
    - Acknowledge the history ("You originally thought X...")
    - Clearly state what the current/latest decision is
    - If a memory is marked [OUTDATED], it was later replaced — mention it briefly

    If memories are from different time periods, say roughly when
    (e.g. "back in March", "more recently", "a few weeks ago").
    """

    /// Formats as `[1] [Mar 3] Blue T-shirt is in the 3rd drawer`.
    static func formatMemories(_ memories: [RetrievedChunk]) -> String {
        memories.enumerated().map { index, chunk in
            let date = memoryDateFormatter.string(from: chunk.createdAt)
            return "[\(index + 1)] [\(date)] \(chunk.cleanText)"
        }.joined(separator: "\n")
    }

    private static let memoryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}
