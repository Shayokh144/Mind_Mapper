import Foundation

nonisolated struct Session: Codable, Equatable, Identifiable, Sendable {
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

    var id: String
    var userId: String
    var title: String?
    var topicTag: TopicTag?
    var summary: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        title: String? = nil,
        topicTag: TopicTag? = nil,
        summary: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.topicTag = topicTag
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
