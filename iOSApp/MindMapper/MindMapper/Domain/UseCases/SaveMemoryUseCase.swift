import Foundation

protocol SaveMemoryUseCaseProtocol {
    func execute(
        text: String,
        sessionId: String,
        userId: String,
        conversationContext: [LLMMessage]
    ) async throws -> String
}

/// STORE pipeline: extract → supersede lookup → embed → atomic SQLite write → vector → ack.
nonisolated final class SaveMemoryUseCase: SaveMemoryUseCaseProtocol, @unchecked Sendable {
    private let memoryRepository: MemoryRepositoryProtocol
    private let vectorRepository: VectorRepositoryProtocol
    private let memoryExtractor: MemoryExtractorProtocol
    private let llmClient: LLMClientProtocol

    init(
        memoryRepository: MemoryRepositoryProtocol,
        vectorRepository: VectorRepositoryProtocol,
        memoryExtractor: MemoryExtractorProtocol,
        llmClient: LLMClientProtocol
    ) {
        self.memoryRepository = memoryRepository
        self.vectorRepository = vectorRepository
        self.memoryExtractor = memoryExtractor
        self.llmClient = llmClient
    }

    func execute(
        text: String,
        sessionId: String,
        userId: String,
        conversationContext: [LLMMessage] = []
    ) async throws -> String {
        let extraction = try await memoryExtractor.extract(
            from: text,
            conversationContext: conversationContext
        )
        let supersedesId = try await resolveSupersedesId(hint: extraction.supersedesHint)
        let embedding = try await llmClient.embed(text: extraction.cleanText, tier: .embed)

        let memory = Memory(
            sessionId: sessionId,
            userId: userId,
            rawText: text,
            cleanText: extraction.cleanText,
            supersedesId: supersedesId
        )
        let entities = extraction.entities.map {
            MemoryEntity(
                memoryId: memory.id,
                entityType: $0.type,
                entityValue: $0.value.lowercased()
            )
        }

        try await memoryRepository.save(
            memory,
            entities: entities,
            superseding: supersedesId
        )
        try await vectorRepository.save(embedding: embedding, memoryId: memory.id)
        return try await acknowledge(rawText: text, conversationContext: conversationContext)
    }

    private func resolveSupersedesId(hint: String?) async throws -> String? {
        guard let hint, !hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let hintEmbedding = try await llmClient.embed(text: hint, tier: .embed)
        let candidates = try await vectorRepository.search(
            queryEmbedding: hintEmbedding,
            topK: 3,
            threshold: 0.80
        )
        return candidates.first?.memoryId
    }

    private func acknowledge(
        rawText: String,
        conversationContext: [LLMMessage]
    ) async throws -> String {
        var messages: [LLMMessage] = [
            LLMMessage(
                role: "system",
                content: """
                You are a warm personal memory assistant. Acknowledge what the user \
                just told you in one friendly sentence. Use prior turns only for \
                coherence (e.g. what "it" refers to). Do not add information they didn't say.
                """
            ),
        ]
        messages.append(contentsOf: conversationContext)
        messages.append(LLMMessage(role: "user", content: rawText))

        let reply = try await llmClient.complete(
            tier: .mini,
            messages: messages,
            maxTokens: 60,
            temperature: 0.7
        )
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.llmResponseInvalid }
        return trimmed
    }
}
