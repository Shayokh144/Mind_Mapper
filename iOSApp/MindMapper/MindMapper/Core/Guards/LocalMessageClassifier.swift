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

        if looksLikePersonalMemory(lower)
            || looksLikePlanResearch(lower)
            || looksLikeSuggestionRequest(lower)
            || looksLikeLinkRecall(lower)
        {
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
        let planResearch = looksLikePlanResearch(lower)
        // Recall of stored plans or a saved URL wins over MIXED (do not add sightseeing).
        if asks && looksLikeRecall(lower) {
            return .query
        }
        if looksLikeLinkRecall(lower) && !stores {
            return .query
        }
        if looksLikeSuggestionRequest(lower) && !stores {
            return .mixed
        }
        if asks && (stores || planResearch) {
            return .mixed
        }
        if asks {
            return .query
        }
        if stores || planResearch {
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
        "who won the", "trivia",
        "debug my", "fix this bug", "compile error",
    ]

    private static let personalNouns = [
        "wife", "husband", "kids", "passport", "keys", "wallet",
        "expense", "bill", "budget", "grocery", "groceries",
        "reminder", "appointment", "trip", "vacation", "bali",
        "t-shirt", "dress", "closet", "drawer", "shelf",
        "outlet", "itinerary", "errand",
        "project", "milestone", "deadline", "roadmap",
    ]

    /// Imperative to-dos / trip errands — in scope even without "I" / "my".
    private static let planPhrases = [
        "need to visit", "have to visit", "must visit",
        "need to buy", "have to buy", "going to visit",
        "when i visit", "when i go to", "next time i",
        "for the trip", "packing list",
        "planning a", "plan a trip", "plan a tour", "tour to",
        "for the project", "on the project", "project plan",
        "need to finish", "need to ship",
    ]

    /// Travel/plan research — in scope; questions route MIXED (need general knowledge).
    private static let planResearchPhrases = [
        "best time to", "best time", "when to visit", "when should i visit",
        "when should we visit", "good time to visit", "time to visit",
        "what to pack", "what should i pack", "what should we pack",
        "where to stay", "where should i stay",
        "weather in", "weather like",
        "things to do in", "what should i do", "what should we do",
        "places to visit", "how long to stay", "how many days",
        "next milestone", "project deadline", "for this project",
        "which country", "budget friendly", "on a budget", "budget tour",
    ]

    /// Asking for a URL the user already saved — in scope QUERY, not web browsing.
    private static let linkRecallPhrases = [
        "the link", "that link", "this link", "the url", "that url",
        "facebook page", "facebook link", "facebook url",
        "know the link", "find the link", "find that link",
        "saved link", "stored link",
    ]

    /// Asking what was already stored — QUERY, not MIXED research.
    private static let recallPhrases = [
        "i planned", "we planned", "did i plan", "did we plan",
        "things i planned", "what i planned", "what we planned",
        "did we decide", "did i decide", "what did we decide", "what did i decide",
        "what do i need to do", "what do we need to do",
        "what's left", "what is left", "left on the",
        "my plans", "our plans", "what are my plans", "what are our plans",
        "what things i planned", "planned to do",
    ]

    private static let planTopicWords = [
        "visit", "trip", "tour", "travel", "itinerary", "packing",
        "project", "milestone", "deadline", "roadmap",
        "country", "budget",
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
        // Noun alone (expense/keys), a plan phrase, or store+pronoun ("I put…").
        return hasNoun || looksLikePersonalPlan(lower) || (hasStore && hasPronoun)
    }

    private static func looksLikePersonalPlan(_ lower: String) -> Bool {
        planPhrases.contains { lower.contains($0) }
    }

    private static func looksLikeRecall(_ lower: String) -> Bool {
        recallPhrases.contains { lower.contains($0) }
    }

    private static func looksLikeLinkRecall(_ lower: String) -> Bool {
        linkRecallPhrases.contains { lower.contains($0) }
    }

    /// Follow-up that should search memories using prior turns ("try again", "that link").
    static func isFollowUpRecall(_ input: String) -> Bool {
        let lower = input.lowercased()
        if looksLikeLinkRecall(lower) { return true }
        return ["try again", "check again", "look again", "once more"]
            .contains { lower.contains($0) }
    }

    private static let suggestionPhrases = [
        "suggest", "recommend", "gift idea", "birthday gift",
        "good gift", "present idea", "present for",
    ]

    private static func looksLikeSuggestionRequest(_ lower: String) -> Bool {
        suggestionPhrases.contains { lower.contains($0) }
    }

    private static func looksLikePlanResearch(_ lower: String) -> Bool {
        if planResearchPhrases.contains(where: { lower.contains($0) }) {
            return true
        }
        guard isQuestion(lower) else { return false }
        return planTopicWords.contains { lower.contains($0) }
    }

    private static func looksLikeStore(_ lower: String) -> Bool {
        storeVerbs.contains { lower.contains($0) }
            || looksLikePersonalPlan(lower)
            || (looksLikePersonalMemory(lower) && !isQuestion(lower))
    }

    private static func isQuestion(_ lower: String) -> Bool {
        let withoutURLs = strippingURLs(lower)
        if withoutURLs.contains("?") { return true }
        return queryStarters.contains { withoutURLs.hasPrefix($0) }
    }

    /// Drop `http(s)` / `www` links so a query string does not look like a question.
    private static func strippingURLs(_ text: String) -> String {
        let pattern = #"https?://\S+|www\.\S+"#
        return text.replacingOccurrences(
            of: pattern,
            with: " ",
            options: .regularExpression
        )
    }

    private static func normalizedChatKey(_ lower: String) -> String {
        lower
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet.punctuationCharacters)
            .lowercased()
    }
}
