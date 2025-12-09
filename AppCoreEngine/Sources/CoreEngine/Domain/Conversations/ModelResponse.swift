import Foundation

public struct ModelResponse: Sendable {
    public let content: String
    public let error: Error?

    public init(content: String, error: Error? = nil) {
        self.content = content
        self.error = error
    }

    public var isSuccess: Bool { error == nil }
}

