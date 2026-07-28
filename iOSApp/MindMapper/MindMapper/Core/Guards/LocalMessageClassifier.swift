import Foundation

/// Cheap local verdicts for scope / intent so free-tier Gemini latency
/// does not block obvious personal-memory turns (e.g. "add water bill to expenses").
/// Ambiguous text returns `nil` → caller falls through to the LLM.
enum LocalMessageClassifier {

    // MARK: - Scope

    /// `.inScope` / `.outOfScope` when confident; `nil` → use ScopeGuard LLM.
    static func scopeVerdict(for input: String) -> ScopeResult? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let lower = text.lowercased()

        if outOfScopeSignals.contains(where: { lower.contains($0) }) {
            return .outOfScope(L10n.Guard.scopeBlocked)
        }

        if looksLikePersonalMemory(lower) {
            return .inScope
        }

        return nil
    }

    // MARK: - Intent

    /// Intent when confident; `nil` → use ClassifyIntent LLM.
    static func intentVerdict(for input: String) -> Intent? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let lower = text.lowercased()

        if chatExact.contains(normalizedChatKey(lower)) {
            return .chat
        }

        let asks = isQuestion(lower)
        let stores = looksLikeStore(lower)
        if asks && stores {
            return .mixed
        }
        if asks {
            return .query
        }
        if stores {
            return .store
        }
        return nil
    }

    // MARK: - Private

    private static let outOfScopeSignals = [
        "homework", "essay", "translate this", "translation of",
        "write a poem", "write an email", "cover letter",
        "diagnose", "prescription", "medical advice", "lawyer",
        "legal advice", "stock tip", "invest in", "crypto advice",
        "who won the", "what is the capital", "trivia",
        "debug my", "fix this bug", "compile error",
    ]

    private static let personalNouns = [
        "wife", "husband", "kids", "passport", "keys", "wallet",
        "expense", "bill", "budget", "grocery", "groceries",
        "reminder", "appointment", "trip", "vacation", "bali",
        "t-shirt", "dress", "closet", "drawer", "shelf",
    ]

    /// Pronouns alone are too noisy ("tell me more"); require a store verb or noun.
    private static let personalPronouns = [
        " my ", " i ", " i'm ", " ive ", " i've ", " we ", " our ",
    ]

    private static let storeVerbs = [
        "add ", "put ", "keep ", "left ", "placed ", "bought ",
        "paid ", "decided ", "need to add", "need to put",
        "remember that", "note that", "save that",
        "in the expense", "to the expense", "on the list",
        "in my ", "to my ",
    ]

    private static let queryStarters = [
        "where ", "what ", "when ", "which ", "who ", "how many ",
        "did i ", "do i ", "have i ", "was i ", "were we ",
        "where's ", "what's ", "when's ",
    ]

    private static let chatExact: Set<String> = [
        "thanks", "thank you", "thx", "ty", "ok", "okay", "cool",
        "great", "got it", "nice", "yes", "yep", "no", "nope",
        "hi", "hello", "hey", "good morning", "good night",
    ]

    private static func looksLikePersonalMemory(_ lower: String) -> Bool {
        let padded = " \(lower) "
        let hasNoun = personalNouns.contains { lower.contains($0) }
        let hasStore = storeVerbs.contains { lower.contains($0) }
        let hasPronoun = personalPronouns.contains { padded.contains($0) }
        // Noun alone (expense/keys) or store+pronoun ("I put…") is enough.
        return hasNoun || (hasStore && hasPronoun)
    }

    private static func looksLikeStore(_ lower: String) -> Bool {
        storeVerbs.contains { lower.contains($0) }
            || (looksLikePersonalMemory(lower) && !isQuestion(lower) && !lower.contains("?"))
    }

    private static func isQuestion(_ lower: String) -> Bool {
        if lower.contains("?") { return true }
        return queryStarters.contains { lower.hasPrefix($0) }
    }

    private static func normalizedChatKey(_ lower: String) -> String {
        lower
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet.punctuationCharacters)
            .lowercased()
    }
}
