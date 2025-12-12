import Foundation
import AppCoreEngine

/// Internal type eraser for CodexClient that preserves Sendable semantics.
/// UIConnections uses this internally; external code should not use it.
internal struct AnyCodexClient: AppCoreEngine.CodexClient {
    internal typealias MessageType = Message
    internal typealias ContextFileType = AppCoreEngine.LoadedFile
    internal typealias OutputPayload = ModelResponse

    private let streamHandler: @Sendable (
        [MessageType],
        [ContextFileType]
    ) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error>

    internal init(
        _ streamHandler: @escaping @Sendable (
            [MessageType],
            [ContextFileType]
        ) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error>
    ) {
        self.streamHandler = streamHandler
    }

    internal func stream(
        messages: [MessageType],
        contextFiles: [ContextFileType]
    ) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error> {
        try await streamHandler(messages, contextFiles)
    }
}

internal extension AnyCodexClient {
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

