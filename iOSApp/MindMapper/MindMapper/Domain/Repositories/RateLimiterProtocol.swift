import Foundation

enum RateResult: Equatable, Sendable {
    case allowed
    case throttled(String)
}

/// Opt out of module-wide `MainActor` default so XCTest can deallocate safely.
nonisolated protocol RateLimiterProtocol: AnyObject {
    func check() -> RateResult
    func recordBlocked()
    func recordAllowed()
}
