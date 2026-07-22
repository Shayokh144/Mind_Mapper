import Foundation

nonisolated struct MemoryEntity: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var memoryId: String
    var entityType: String
    var entityValue: String

    init(
        id: String = UUID().uuidString,
        memoryId: String,
        entityType: String,
        entityValue: String
    ) {
        self.id = id
        self.memoryId = memoryId
        self.entityType = entityType
        self.entityValue = entityValue
    }
}
