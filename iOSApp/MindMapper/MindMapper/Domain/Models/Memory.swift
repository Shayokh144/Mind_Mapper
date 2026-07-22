import Foundation

nonisolated struct Memory: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var sessionId: String
    var userId: String
    var rawText: String
    var cleanText: String
    var supersedesId: String?
    var isSuperseded: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        userId: String,
        rawText: String,
        cleanText: String,
        supersedesId: String? = nil,
        isSuperseded: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.userId = userId
        self.rawText = rawText
        self.cleanText = cleanText
        self.supersedesId = supersedesId
        self.isSuperseded = isSuperseded
        self.createdAt = createdAt
    }
}
