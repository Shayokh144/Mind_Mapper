import Foundation

/// UI-ready chat bubble row (no SwiftUI types — View applies theme).
struct MessageDisplayModel: Identifiable, Equatable, Sendable {
    let id: String
    let role: String
    let content: String
    let createdAt: Date
    /// Scope-blocked / caution assistant replies — `ChatBubble(isWarning:)`.
    let isWarning: Bool

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }

    init(
        id: String = UUID().uuidString,
        role: String,
        content: String,
        createdAt: Date = Date(),
        isWarning: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.isWarning = isWarning
    }

    init(from message: Message, isWarning: Bool = false) {
        id = message.id
        role = message.role
        content = message.content
        createdAt = message.createdAt
        self.isWarning = isWarning
    }
}
