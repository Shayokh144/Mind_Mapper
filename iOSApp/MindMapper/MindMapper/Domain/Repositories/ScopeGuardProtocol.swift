import Foundation

enum ScopeResult: Equatable, Sendable {
    case inScope
    case outOfScope(String)
}

protocol ScopeGuardProtocol {
    func check(_ input: String) async throws -> ScopeResult
}
