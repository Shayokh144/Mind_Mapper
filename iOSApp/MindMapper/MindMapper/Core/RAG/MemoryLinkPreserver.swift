import Foundation

/// Keeps URLs and local file paths from the user's note when the extractor paraphrases them away.
enum MemoryLinkPreserver {
    private static let trailingJunk = CharacterSet(charactersIn: ".,;:!?)]}>\"'")
    private static let pathRegex = try? NSRegularExpression(
        pattern: #"(?:file://\S+|/Users/\S+|~/\S+)"#
    )

    static func mergingLinks(from rawText: String, into cleanText: String) -> String {
        var result = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
        for link in links(in: rawText) {
            guard !contains(link, in: result) else { continue }
            if result.isEmpty {
                result = link
            } else {
                result += " \(link)"
            }
        }
        return result
    }

    static func addingURLEntities(
        _ entities: [ExtractionResult.EntityItem],
        from rawText: String
    ) -> [ExtractionResult.EntityItem] {
        var result = entities
        for link in links(in: rawText) {
            let already = result.contains {
                $0.type.lowercased() == "url"
                    && $0.value.compare(link, options: .caseInsensitive) == .orderedSame
            }
            if !already {
                result.append(.init(type: "url", value: link))
            }
        }
        return result
    }

    static func links(in text: String) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for candidate in detectedWebLinks(in: text) + pathLinks(in: text) {
            let trimmed = trimTrailingJunk(candidate)
            guard trimmed.count >= 4 else { continue }
            if ordered.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) }) {
                continue
            }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                ordered.append(trimmed)
            }
        }
        return ordered
    }

    private static func contains(_ link: String, in text: String) -> Bool {
        text.range(of: link, options: .caseInsensitive) != nil
    }

    private static func detectedWebLinks(in text: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, options: [], range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private static func pathLinks(in text: String) -> [String] {
        guard let regex = pathRegex else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private static func trimTrailingJunk(_ value: String) -> String {
        var trimmed = value
        while let last = trimmed.unicodeScalars.last, trailingJunk.contains(last) {
            trimmed.removeLast()
        }
        return trimmed
    }
}

extension ExtractionResult {
    func preservingLinks(from rawText: String) -> ExtractionResult {
        ExtractionResult(
            cleanText: MemoryLinkPreserver.mergingLinks(from: rawText, into: cleanText),
            entities: MemoryLinkPreserver.addingURLEntities(entities, from: rawText),
            supersedesHint: supersedesHint,
            shouldSetNotification: shouldSetNotification,
            notificationTitle: notificationTitle,
            notificationDescription: notificationDescription,
            notificationDatetime: notificationDatetime,
            notificationRecurrence: notificationRecurrence
        )
    }
}
