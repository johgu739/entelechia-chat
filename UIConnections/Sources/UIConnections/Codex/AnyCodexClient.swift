import Foundation
import AppCoreEngine

/// Type eraser for CodexClient that preserves Sendable semantics.
/// Used by AppComposition to provide type-erased clients to engines.
public struct AnyCodexClient: AppCoreEngine.CodexClient {
    public typealias MessageType = Message
    public typealias ContextFileType = AppCoreEngine.LoadedFile
    public typealias OutputPayload = ModelResponse

    private let streamHandler: @Sendable (
        [MessageType],
        [ContextFileType]
    ) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error>

    public init(
        _ streamHandler: @escaping @Sendable (
            [MessageType],
            [ContextFileType]
        ) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error>
    ) {
        self.streamHandler = streamHandler
    }

    public func stream(
        messages: [MessageType],
        contextFiles: [ContextFileType]
    ) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error> {
        try await streamHandler(messages, contextFiles)
    }
}

public extension AnyCodexClient {
    static func stub() -> AnyCodexClient {
        AnyCodexClient { _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(AppCoreEngine.StreamChunk.output(ModelResponse(content: "Stub response")))
                continuation.yield(AppCoreEngine.StreamChunk.done)
                continuation.finish()
            }
        }
    }
}

