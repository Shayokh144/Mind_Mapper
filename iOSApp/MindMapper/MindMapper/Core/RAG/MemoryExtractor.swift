import Foundation

struct ExtractionResult: Equatable, Sendable {
    let cleanText: String
    let entities: [EntityItem]
    let supersedesHint: String?
    let shouldSetNotification: Bool
    let notificationTitle: String?
    let notificationDescription: String?
    let notificationDatetime: Date?
    let notificationRecurrence: ReminderRecurrence?

    struct EntityItem: Decodable, Equatable, Sendable {
        let type: String
        let value: String
    }

    init(
        cleanText: String,
        entities: [EntityItem],
        supersedesHint: String?,
        shouldSetNotification: Bool = false,
        notificationTitle: String? = nil,
        notificationDescription: String? = nil,
        notificationDatetime: Date? = nil,
        notificationRecurrence: ReminderRecurrence? = nil
    ) {
        self.cleanText = cleanText
        self.entities = entities
        self.supersedesHint = supersedesHint
        self.shouldSetNotification = shouldSetNotification
        self.notificationTitle = notificationTitle
        self.notificationDescription = notificationDescription
        self.notificationDatetime = notificationDatetime
        self.notificationRecurrence = notificationRecurrence
    }

    var reminderProposal: ReminderProposal? {
        guard shouldSetNotification else { return nil }
        return ReminderProposal(
            shouldSetNotification: true,
            title: Self.trimmedOrNil(notificationTitle),
            description: Self.trimmedOrNil(notificationDescription),
            fireAt: notificationDatetime,
            recurrence: notificationRecurrence
        )
    }

    private static func trimmedOrNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    enum CodingKeys: String, CodingKey {
        case cleanText = "clean_text"
        case entities
        case supersedesHint = "supersedes_hint"
        case shouldSetNotification = "should_set_notification"
        case notificationTitle = "notification_title"
        case notificationDescription = "notification_description"
        case notificationDatetime = "notification_datetime"
        case notificationRecurrence = "notification_recurrence"
    }
}

extension ExtractionResult: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cleanText = try container.decode(String.self, forKey: .cleanText)
        entities = try container.decodeIfPresent([EntityItem].self, forKey: .entities) ?? []
        supersedesHint = try container.decodeIfPresent(String.self, forKey: .supersedesHint)
        shouldSetNotification = try container.decodeIfPresent(Bool.self, forKey: .shouldSetNotification)
            ?? false
        notificationTitle = try container.decodeIfPresent(String.self, forKey: .notificationTitle)
        notificationDescription = try container.decodeIfPresent(String.self, forKey: .notificationDescription)
        let datetimeRaw = try container.decodeIfPresent(String.self, forKey: .notificationDatetime)
        notificationDatetime = ReminderDateParser.parse(datetimeRaw)
        let recurrenceRaw = try container.decodeIfPresent(String.self, forKey: .notificationRecurrence)
        notificationRecurrence = recurrenceRaw.flatMap(ReminderRecurrence.init(rawValue:))
    }
}

protocol MemoryExtractorProtocol {
    func extract(
        from rawText: String,
        conversationContext: [LLMMessage]
    ) async throws -> ExtractionResult
}

/// Pulls a normalised fact + entities from a STORE message via `tier: .mini`.
nonisolated struct MemoryExtractor: MemoryExtractorProtocol, @unchecked Sendable {
    private let llmClient: LLMClientProtocol

    init(llmClient: LLMClientProtocol) {
        self.llmClient = llmClient
    }

    func extract(
        from rawText: String,
        conversationContext: [LLMMessage] = []
    ) async throws -> ExtractionResult {
        do {
            return try await requestExtraction(rawText, conversationContext: conversationContext)
        } catch {
            // Don't immediately retry quota/rate-limit — Google asks to wait ~30–60s.
            if Self.isQuotaOrRateLimited(error) {
                throw error
            }
            // One retry — Gemini Flash sometimes returns truncated / empty JSON.
            AppLogger.error("Memory extraction decode failed; retrying once", error: error)
            return try await requestExtraction(rawText, conversationContext: conversationContext)
        }
    }

    private static func isQuotaOrRateLimited(_ error: Error) -> Bool {
        if let appError = error as? AppError {
            switch appError {
            case .rateLimitExceeded:
                return true
            case let .llmCallFailed(underlying):
                let text = String(describing: underlying).lowercased()
                return text.contains("429")
                    || text.contains("quota")
                    || text.contains("resource_exhausted")
            default:
                break
            }
        }
        let text = String(describing: error).lowercased()
        return text.contains("429") || text.contains("quota")
    }

    private func requestExtraction(
        _ rawText: String,
        conversationContext: [LLMMessage]
    ) async throws -> ExtractionResult {
        let systemPrompt = """
        You are a personal memory extraction assistant.
        Extract structured information from the latest user message.
        Prior conversation turns (if any) are only for resolving pronouns and incomplete \
        references (e.g. "it" → the passport mentioned earlier). Do NOT merge the whole \
        thread into one memory — output one clean_text for the NEW fact only.
        Reply ONLY with valid JSON, no other text. Keep the JSON compact.

        JSON format:
        {
          "clean_text": "normalised fact in standalone form",
          "entities": [
            { "type": "person|category|topic_id|product|location|url", "value": "the value" }
          ],
          "supersedes_hint": "word or phrase suggesting this replaces an older decision, or null",
          "should_set_notification": true,
          "notification_title": "short title or null",
          "notification_description": "notification body or null",
          "notification_datetime": "ISO-8601 datetime with offset, or null if time is unclear",
          "notification_recurrence": "once|daily|weekly|monthly or null"
        }

        Rules:
        - clean_text must be a complete standalone fact (no pronouns like "it" or "there")
        - If the user included a URL or local file path, copy it into clean_text exactly. \
          Never drop, shorten, or paraphrase a link as "a website" or "an online store".
        - Extract ALL meaningful entities (typically 1–5). Use type "url" for links.
        - topic_id should be a snake_case stable identifier (e.g. "gift_wife_anniversary")
        - supersedes_hint: look for words like "instead", "actually", "changed my mind", "no longer"
        - should_set_notification: true when the user asks to be reminded OR the fact is an
          actionable future follow-up (medicine, ask HR, deadline, appointment). False for
          casual chat or facts with no follow-up.
        - If remindable but the time is unclear (e.g. "I need to ask office HR about leave"),
          still set should_set_notification true and send null for datetime (and recurrence
          if unclear). Never invent a time.
        - Example: "eat medicine tomorrow at 10 PM" → should_set_notification true,
          notification_title like "Take medicine", datetime filled, recurrence "once".
        - Example: "ask HR about leave policy" → should_set_notification true, datetime null.
        - Do NOT assume a reminder should already be scheduled — the app will confirm with the user.
        """

        var messages: [LLMMessage] = [
            LLMMessage(role: "system", content: systemPrompt),
        ]
        messages.append(contentsOf: conversationContext)
        messages.append(LLMMessage(role: "user", content: rawText))

        let json = try await llmClient.complete(
            tier: .mini,
            messages: messages,
            // Compact JSON; proxy also sets responseMimeType=application/json when temp=0.
            maxTokens: 768,
            temperature: 0
        )

        return try Self.decode(json).preservingLinks(from: rawText)
    }

    static func decode(_ raw: String) throws -> ExtractionResult {
        let cleaned = extractJSONObject(from: stripCodeFences(raw))
        guard let data = cleaned.data(using: .utf8), !cleaned.isEmpty else {
            AppLogger.error("Memory extraction JSON empty after cleanup. raw=\(raw.prefix(300))")
            throw AppError.llmResponseInvalid
        }
        do {
            return try JSONDecoder().decode(ExtractionResult.self, from: data)
        } catch {
            AppLogger.error(
                "Failed to decode memory extraction JSON. raw=\(cleaned.prefix(500))",
                error: error
            )
            throw AppError.llmResponseInvalid
        }
    }

    /// Pull the outermost `{ ... }` so preamble / trailing prose does not break decoding.
    static func extractJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start < end
        else {
            return trimmed
        }
        return String(trimmed[start...end])
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
