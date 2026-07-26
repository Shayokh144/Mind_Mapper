import Foundation

/// Routing label for a sanitised, in-scope user message.
/// Safe default when unclear: `.chat` (no memory save or retrieval).
enum Intent: String, Equatable, Sendable {
    case store = "STORE"
    case query = "QUERY"
    case mixed = "MIXED"
    case chat = "CHAT"
}
