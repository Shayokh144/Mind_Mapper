import Foundation

/// Layer 0/3 — hourly message cap + cooldown after consecutive blocks.
/// `nonisolated` opts out of `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
nonisolated final class RateLimiter: RateLimiterProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var messageCount = 0
    private var consecutiveBlockedCount = 0
    private var windowStart = Date()
    private var cooldownUntil: Date?

    private let maxMessagesPerHour = 30
    private let maxConsecutiveBlocks = 5
    private let cooldownSeconds: TimeInterval = 60
    private let hourSeconds: TimeInterval = 3600

    func check() -> RateResult {
        lock.lock()
        defer { lock.unlock() }

        let current = Date()
        resetHourlyWindowIfNeeded(at: current)

        if let until = cooldownUntil, current < until {
            let remaining = max(1, Int(ceil(until.timeIntervalSince(current))))
            return .throttled("Too many out-of-scope requests. Wait \(remaining)s.")
        }

        if messageCount >= maxMessagesPerHour {
            return .throttled("You've sent many messages this hour. Take a short break.")
        }

        messageCount += 1
        return .allowed
    }

    func recordBlocked() {
        lock.lock()
        defer { lock.unlock() }

        consecutiveBlockedCount += 1
        if consecutiveBlockedCount >= maxConsecutiveBlocks {
            cooldownUntil = Date().addingTimeInterval(cooldownSeconds)
            consecutiveBlockedCount = 0
        }
    }

    func recordAllowed() {
        lock.lock()
        defer { lock.unlock() }
        consecutiveBlockedCount = 0
    }

    private func resetHourlyWindowIfNeeded(at current: Date) {
        if current.timeIntervalSince(windowStart) > hourSeconds {
            messageCount = 0
            windowStart = current
        }
    }
}
