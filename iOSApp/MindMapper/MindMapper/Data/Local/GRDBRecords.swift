import Foundation
import GRDB

// MARK: - Shared column naming (camelCase properties ↔ snake_case columns)

nonisolated private enum GRDBSnakeCase: Sendable {
    static let decoding: DatabaseColumnDecodingStrategy = .convertFromSnakeCase
    static let encoding: DatabaseColumnEncodingStrategy = .convertToSnakeCase
}

// MARK: - UserRecord

nonisolated struct UserRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    var id: String
    var email: String
    var displayName: String?
    var createdAt: Date

    static let databaseTableName = "users"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { GRDBSnakeCase.decoding }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { GRDBSnakeCase.encoding }

    init(from user: User) {
        id = user.id
        email = user.email
        displayName = user.displayName
        createdAt = user.createdAt
    }

    var domainModel: User {
        User(id: id, email: email, displayName: displayName, createdAt: createdAt)
    }
}

// MARK: - SessionRecord

nonisolated struct SessionRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    var id: String
    var userId: String
    var title: String?
    var topicTag: String?
    var summary: String?
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "sessions"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { GRDBSnakeCase.decoding }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { GRDBSnakeCase.encoding }

    init(from session: Session) {
        id = session.id
        userId = session.userId
        title = session.title
        topicTag = session.topicTag?.rawValue
        summary = session.summary
        createdAt = session.createdAt
        updatedAt = session.updatedAt
    }

    var domainModel: Session {
        Session(
            id: id,
            userId: userId,
            title: title,
            topicTag: topicTag.flatMap(Session.TopicTag.init(rawValue:)),
            summary: summary,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - MessageRecord

nonisolated struct MessageRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    var id: String
    var sessionId: String
    var role: String
    var content: String
    var createdAt: Date

    static let databaseTableName = "messages"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { GRDBSnakeCase.decoding }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { GRDBSnakeCase.encoding }

    init(from message: Message) {
        id = message.id
        sessionId = message.sessionId
        role = message.role
        content = message.content
        createdAt = message.createdAt
    }

    var domainModel: Message {
        Message(id: id, sessionId: sessionId, role: role, content: content, createdAt: createdAt)
    }
}

// MARK: - MemoryRecord

nonisolated struct MemoryRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    var id: String
    var sessionId: String
    var userId: String
    var rawText: String
    var cleanText: String
    var supersedesId: String?
    var isSuperseded: Bool
    var createdAt: Date

    static let databaseTableName = "memories"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { GRDBSnakeCase.decoding }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { GRDBSnakeCase.encoding }

    init(from memory: Memory) {
        id = memory.id
        sessionId = memory.sessionId
        userId = memory.userId
        rawText = memory.rawText
        cleanText = memory.cleanText
        supersedesId = memory.supersedesId
        isSuperseded = memory.isSuperseded
        createdAt = memory.createdAt
    }

    var domainModel: Memory {
        Memory(
            id: id,
            sessionId: sessionId,
            userId: userId,
            rawText: rawText,
            cleanText: cleanText,
            supersedesId: supersedesId,
            isSuperseded: isSuperseded,
            createdAt: createdAt
        )
    }
}

// MARK: - MemoryEntityRecord

nonisolated struct MemoryEntityRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    var id: String
    var memoryId: String
    var entityType: String
    var entityValue: String

    static let databaseTableName = "memory_entities"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { GRDBSnakeCase.decoding }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { GRDBSnakeCase.encoding }

    init(from entity: MemoryEntity) {
        id = entity.id
        memoryId = entity.memoryId
        entityType = entity.entityType
        entityValue = entity.entityValue
    }

    var domainModel: MemoryEntity {
        MemoryEntity(id: id, memoryId: memoryId, entityType: entityType, entityValue: entityValue)
    }
}

// MARK: - VectorRecord

nonisolated struct VectorRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    var id: String
    var memoryId: String
    var embedding: Data
    var createdAt: Date

    static let databaseTableName = "vectors"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { GRDBSnakeCase.decoding }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { GRDBSnakeCase.encoding }

    init(from vector: Vector) {
        id = vector.id
        memoryId = vector.memoryId
        embedding = vector.embedding
        createdAt = vector.createdAt
    }

    var domainModel: Vector {
        Vector(id: id, memoryId: memoryId, embedding: embedding, createdAt: createdAt)
    }
}
