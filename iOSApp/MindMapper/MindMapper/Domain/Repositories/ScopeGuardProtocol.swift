import Foundation

enum ScopeResult: Equatable, Sendable {
    case inScope
    case outOfScope(String)
}

nonisolated protocol ScopeGuardProtocol: Sendable {
    func check(_ input: String) async throws -> ScopeResult
}
