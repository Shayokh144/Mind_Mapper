import Foundation

protocol CloseSessionUseCaseProtocol {
    func execute(sessionId: String) async throws
}

/// Generates title, topic tag, and summary for a session, then embeds each summary bullet.
nonisolated final class CloseSessionUseCase: CloseSessionUseCaseProtocol, @unchecked Sendable {
    private let messageRepository: MessageRepositoryProtocol
    private let sessionRepository: SessionRepositoryProtocol
    private let memoryRepository: MemoryRepositoryProtocol
    private let vectorRepository: VectorRepositoryProtocol
    private let llmClient: LLMClientProtocol

    init(
        messageRepository: MessageRepositoryProtocol,
        sessionRepository: SessionRepositoryProtocol,
        memoryRepository: MemoryRepositoryProtocol,
        vectorRepository: VectorRepositoryProtocol,
        llmClient: LLMClientProtocol
    ) {
        self.messageRepository = messageRepository
        self.sessionRepository = sessionRepository
        self.memoryRepository = memoryRepository
        self.vectorRepository = vectorRepository
        self.llmClient = llmClient
    }

    func execute(sessionId: String) async throws {
        let messages = try await messageRepository.fetchAll(for: sessionId)
        guard !messages.isEmpty else { return }

        guard var session = try await sessionRepository.fetch(id: sessionId) else {
            throw AppError.notFound(entityType: "session", id: sessionId)
        }

        let transcript = messages.map {
            "\($0.role.capitalized): \($0.content)"
        }.joined(separator: "\n")

        async let titleTopic = generateTitleAndTopic(transcript: transcript)
        async let summaryText = generateSummary(transcript: transcript)
        let (titleResult, summary) = try await (titleTopic, summaryText)

        // Preserve user-edited title/tag from the list sheet — do not overwrite with LLM.
        let hasUserTitle = !(session.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasUserTag = session.topicTag != nil
        if !hasUserTitle {
            session.title = titleResult.title
        }
        if !hasUserTag {
            session.topicTag = .builtIn(titleResult.topic)
        }
        session.summary = summary
        session.updatedAt = Date()
        try await sessionRepository.update(session)

        try await replaceSummaryMemories(
            sessionId: sessionId,
            userId: session.userId,
            summary: summary
        )
    }

    // MARK: - LLM

    private struct TitleTopicResult: Sendable {
        let title: String
        let topic: Session.TopicTag
    }

    private struct TitleResponse: Decodable {
        let title: String
        let topic: String
    }

    private func generateTitleAndTopic(transcript: String) async throws -> TitleTopicResult {
        let topicList = Session.TopicTag.allCases.map(\.rawValue).joined(separator: ", ")
        let prompt = """
            Given this conversation, provide:
            1. A 5-word title
            2. One topic tag from: \(topicList)

            Reply ONLY with JSON: {"title": "...", "topic": "..."}

            Conversation:
            \(transcript)
            """

        let raw = try await llmClient.complete(
            tier: .nano,
            messages: [LLMMessage(role: "user", content: prompt)],
            maxTokens: 50,
            temperature: 0
        )

        let decoded = try Self.decodeTitleResponse(raw)
        let topic = Session.TopicTag(rawValue: decoded.topic.lowercased()) ?? .other
        let title = decoded.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw AppError.llmResponseInvalid }
        return TitleTopicResult(title: title, topic: topic)
    }

    private func generateSummary(transcript: String) async throws -> String {
        let prompt = """
            Summarise this conversation as 3-5 bullet points covering:
            - Key facts mentioned
            - Decisions made
            - Open questions or plans

            Write each bullet as a complete standalone sentence.
            Conversation:
            \(transcript)
            """

        let summary = try await llmClient.complete(
            tier: .mini,
            messages: [LLMMessage(role: "user", content: prompt)],
            maxTokens: 300,
            temperature: 0.3
        )
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.llmResponseInvalid }
        return trimmed
    }

    // MARK: - Summary memories

    private func replaceSummaryMemories(
        sessionId: String,
        userId: String,
        summary: String
    ) async throws {
        try await deleteExistingSummaryMemories(sessionId: sessionId, userId: userId)

        let bullets = Self.parseBullets(summary)
        for bulletText in bullets.prefix(5) {
            let embedding = try await llmClient.embed(text: bulletText, tier: .embed)
            let memory = Memory(
                sessionId: sessionId,
                userId: userId,
                rawText: "[Session summary] \(bulletText)",
                cleanText: bulletText
            )
            try await memoryRepository.save(memory)
            try await vectorRepository.save(embedding: embedding, memoryId: memory.id)
        }
    }

    private func deleteExistingSummaryMemories(sessionId: String, userId: String) async throws {
        let existing = try await memoryRepository.fetchAll(for: userId)
            .filter {
                $0.sessionId == sessionId && $0.rawText.hasPrefix("[Session summary]")
            }
        for memory in existing {
            try await memoryRepository.delete(memory.id)
        }
    }

    // MARK: - Parsing

    private static func decodeTitleResponse(_ raw: String) throws -> TitleResponse {
        let cleaned = stripCodeFences(raw)
        guard let data = cleaned.data(using: .utf8) else {
            throw AppError.llmResponseInvalid
        }
        do {
            return try JSONDecoder().decode(TitleResponse.self, from: data)
        } catch {
            AppLogger.error("Failed to decode session title JSON", error: error)
            throw AppError.llmResponseInvalid
        }
    }

    static func parseBullets(_ summary: String) -> [String] {
        summary
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line in
                var text = line
                while text.hasPrefix("-") || text.hasPrefix("•") || text.hasPrefix("*") {
                    text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                return text
            }
            .filter { !$0.isEmpty }
    }

    static func stripCodeFences(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.hasPrefix("```") else { return result }

        if let firstNewline = result.firstIndex(of: "\n") {
            result = String(result[result.index(after: firstNewline)...])
        }
        if let fence = result.range(of: "```", options: .backwards) {
            result = String(result[..<fence.lowerBound])
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
