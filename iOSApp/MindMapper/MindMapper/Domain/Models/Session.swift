import Foundation

nonisolated struct Session: Codable, Equatable, Identifiable, Sendable {
    /// Fixed tags used by the close-session LLM and built-in icon/color mapping.
    enum TopicTag: String, Codable, CaseIterable, Sendable {
        case wardrobe
        case plans
        case locations
        case people
        case ideas
        case gifts
        case work
        case health
        case other
    }

    /// Built-in enum tag or a user-created free-form label (stored in `topic_tag`).
    enum Topic: Equatable, Sendable, Codable {
        case builtIn(TopicTag)
        case custom(String)

        init?(stored: String) {
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if let builtIn = TopicTag(rawValue: trimmed.lowercased()) {
                self = .builtIn(builtIn)
            } else {
                self = .custom(trimmed)
            }
        }

        /// Value written to SQLite `topic_tag`.
        var storageValue: String {
            switch self {
            case let .builtIn(tag):
                return tag.rawValue
            case let .custom(label):
                return label
            }
        }

        var displayLabel: String {
            switch self {
            case let .builtIn(tag):
                return tag.rawValue.capitalized
            case let .custom(label):
                return label
            }
        }

        var builtInTag: TopicTag? {
            if case let .builtIn(tag) = self { return tag }
            return nil
        }

        var isCustom: Bool {
            if case .custom = self { return true }
            return false
        }
    }

    var id: String
    var userId: String
    var title: String?
    var topicTag: Topic?
    var summary: String?
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        title: String? = nil,
        topicTag: Topic? = nil,
        summary: String? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.topicTag = topicTag
        self.summary = summary
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
