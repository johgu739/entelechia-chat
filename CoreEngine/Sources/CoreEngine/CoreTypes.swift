import Foundation

/// Configuration values that must be injected from the host (paths, env, credentials).
public struct EngineConfig: Sendable {
    public var baseURL: URL?
    public var environment: [String: String]

    public init(baseURL: URL? = nil, environment: [String: String] = [:]) {
        self.baseURL = baseURL
        self.environment = environment
    }
}

/// Generic stream chunk used by CodexClient; concrete payloads are defined by adapters.
public enum StreamChunk<Output: Sendable>: Sendable {
    case token(String)
    case output(Output)
    case done
}

