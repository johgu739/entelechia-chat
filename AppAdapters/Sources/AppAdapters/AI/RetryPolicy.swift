import Foundation

public struct BackoffPolicy: Sendable {
    public let baseDelay: TimeInterval
    public let factor: Double
    public let maxDelay: TimeInterval

    public init(baseDelay: TimeInterval = 0.5, factor: Double = 2.0, maxDelay: TimeInterval = 8.0) {
        self.baseDelay = baseDelay
        self.factor = factor
        self.maxDelay = maxDelay
    }

    public func delay(for attempt: Int) -> TimeInterval {
        let computed = baseDelay * pow(factor, Double(attempt))
        return min(computed, maxDelay)
    }
}

public struct RetryPolicy: Sendable {
    public let maxRetries: Int
    public let backoff: BackoffPolicy

    public init(maxRetries: Int = 2, backoff: BackoffPolicy = BackoffPolicy()) {
        self.maxRetries = maxRetries
        self.backoff = backoff
    }
}

