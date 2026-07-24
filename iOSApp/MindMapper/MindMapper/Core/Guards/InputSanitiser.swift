import Foundation

enum SanitiseResult: Equatable, Sendable {
    case allowed(String)
    case blocked(String)
}

/// Layer 1 input guard — length, code, URLs/paths, then injection strip.
/// Always run before any LLM call (scope guard / intent / chat).
struct InputSanitiser {

    static let maxCharacters = 500

    static func process(_ raw: String) -> SanitiseResult {
        if raw.count > maxCharacters {
            return .blocked("Please keep messages under 500 characters.")
        }

        if containsCodeSignal(raw) {
            return .blocked("This app is for personal memories, not code.")
        }

        if containsURLOrPath(raw) {
            return .blocked("I can only store personal notes and facts.")
        }

        let cleaned = stripInjectionPhrases(raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return .allowed(cleaned)
    }

    // MARK: - Steps

    private static func containsCodeSignal(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        let signals = [
            "```",
            "func ",
            "def ",
            "class ",
            "import ",
            "  return ",
            "select ",
            "insert ",
            "<?php",
            "public void",
            "println(",
            "console.log",
            "debug this",
            "swift code",
            "write code",
            "code for me",
        ]
        return signals.contains { lower.contains($0) }
    }

    private static func containsURLOrPath(_ raw: String) -> Bool {
        let pattern = #"https?://|www\.|/Users/|C:\\|file://"#
        return raw.range(of: pattern, options: .regularExpression) != nil
    }

    private static func stripInjectionPhrases(_ raw: String) -> String {
        var cleaned = raw
        let patterns = [
            #"ignore (all )?previous instructions"#,
            #"you are now"#,
            #"forget (your|all) (rules|instructions)"#,
            #"pretend (you are|to be)"#,
            #"jailbreak"#,
            #"developer mode"#,
            #"system prompt"#,
        ]
        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "[removed]",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return cleaned
    }
}
