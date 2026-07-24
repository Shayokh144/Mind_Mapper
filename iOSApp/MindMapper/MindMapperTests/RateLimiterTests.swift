import XCTest
@testable import MindMapper

final class RateLimiterTests: XCTestCase {
    func test_fiveConsecutiveBlocks_triggersCooldown() {
        let limiter = RateLimiter()

        for _ in 0..<5 {
            switch limiter.check() {
            case .allowed:
                break
            case .throttled(let message):
                XCTFail("Unexpected throttle before 5 blocks: \(message)")
                return
            }
            limiter.recordBlocked()
        }

        switch limiter.check() {
        case .throttled(let message):
            XCTAssertTrue(message.lowercased().contains("wait"))
        case .allowed:
            XCTFail("Expected throttled after 5 consecutive blocks")
        }
    }

    func test_recordAllowed_resetsConsecutiveBlockCount() {
        let limiter = RateLimiter()

        for _ in 0..<4 {
            switch limiter.check() {
            case .allowed:
                break
            case .throttled(let message):
                XCTFail("Unexpected throttle: \(message)")
                return
            }
            limiter.recordBlocked()
        }
        limiter.recordAllowed()

        switch limiter.check() {
        case .allowed:
            break
        case .throttled:
            XCTFail("Expected allowed after reset")
            return
        }
        limiter.recordBlocked()

        switch limiter.check() {
        case .throttled:
            XCTFail("Cooldown must not trigger after consecutive count reset")
        case .allowed:
            break
        }
    }
}
