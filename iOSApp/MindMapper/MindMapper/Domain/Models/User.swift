import Foundation

nonisolated struct User: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var email: String
    var displayName: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
    }
}
