import Foundation

/// Abstract Codex/model client.
public protocol CodexClient: Sendable {
    associatedtype MessageType: Sendable
    associatedtype ContextFileType: Sendable
    associatedtype OutputPayload: Sendable

    func stream(
        messages: [MessageType],
        contextFiles: [ContextFileType]
    ) async throws -> AsyncThrowingStream<StreamChunk<OutputPayload>, Error>
}

