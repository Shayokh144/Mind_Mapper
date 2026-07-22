import Foundation

nonisolated struct Message: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var sessionId: String
    var role: String
    var content: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        role: String,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
