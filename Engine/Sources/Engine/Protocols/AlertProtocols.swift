/// UI host supplies an alert sink; Engine emits typed errors through it.
public protocol AlertSink: Sendable {
    func emit(_ error: Error)
}

