import Foundation

/// Errors emitted by streaming transports (SSE/WS).
public enum StreamTransportError: Error, Sendable {
    case invalidResponse(String)
    case framing(String)
    case decoding(String)
    case timedOut
    case cancelled
    case terminatedEarly
    case underlying(String)
}

