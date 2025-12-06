import Foundation
import CoreEngine

/// Minimal Codex client adapter placeholder; replace with real networked client.
public struct CodexClientAdapter: CodexClient, @unchecked Sendable {
    public typealias MessageType = Message
    public typealias ContextFileType = LoadedFile
    public typealias OutputPayload = ModelResponse

    public init() {}

    public func stream(
        messages: [Message],
        contextFiles: [LoadedFile]
    ) async throws -> AsyncThrowingStream<StreamChunk<ModelResponse>, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.output(ModelResponse(content: "Stub response")))
            continuation.yield(.done)
            continuation.finish()
        }
    }
}

