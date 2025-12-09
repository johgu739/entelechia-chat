import AppCoreEngine

/// Alert sink that ignores errors (placeholder).
public struct NullAlertSink: AlertSink {
    public init() {}
    public func emit(_ error: Error) {}
}

