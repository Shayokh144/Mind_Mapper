import Foundation

/// Single source of truth for chat length and LLM rolling-window limits.
enum ChatLimits {
    /// Aliases `InputSanitiser.maxCharacters` (500) — do not fork a second constant.
    static var maxCharactersPerMessage: Int { InputSanitiser.maxCharacters }

    /// Total `messages` rows (user + assistant) allowed in one session.
    static let maxMessagesPerSession = 40

    /// Prior + current bubbles included in LLM payloads (≈ 6 turns).
    static let rollingContextMessageCount = 12

    /// Shorter tail for intent classification.
    static let intentContextMessageCount = 4

    /// Need room for this user message **and** the coming assistant reply.
    static func isAtMessageLimit(currentCount: Int) -> Bool {
        currentCount >= maxMessagesPerSession - 1
    }

    static func remainingMessageSlots(currentCount: Int) -> Int {
        max(0, maxMessagesPerSession - currentCount)
    }

    /// 0 = empty session, 1 = at capacity — drives the quota bar fill + color.
    static func usageFraction(currentCount: Int) -> Double {
        guard maxMessagesPerSession > 0 else { return 0 }
        return min(1, Double(currentCount) / Double(maxMessagesPerSession))
    }

    /// Last `limit` messages in chronological order (oldest → newest).
    static func rollingContext(
        from messages: [Message],
        limit: Int = rollingContextMessageCount
    ) -> [Message] {
        guard limit > 0 else { return [] }
        return Array(messages.suffix(limit))
    }

    static func llmMessages(from messages: [Message]) -> [LLMMessage] {
        messages.map { LLMMessage(role: $0.role, content: $0.content) }
    }

    /// Drops a trailing user turn that matches `currentText` so callers can append it once.
    static func llmMessagesExcludingTrailingUser(
        from messages: [Message],
        currentText: String
    ) -> [LLMMessage] {
        var slice = messages
        if let last = slice.last,
           last.role == "user",
           last.content == currentText
        {
            slice.removeLast()
        }
        return llmMessages(from: slice)
    }
}
