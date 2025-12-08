import Foundation
import CoreEngine

/// Minimal Codex client adapter placeholder; replace with real networked client.
public struct CodexClientAdapter: CodexClient, Sendable {
    public typealias MessageType = Message
    public typealias ContextFileType = LoadedFile
    public typealias OutputPayload = ModelResponse

    public init() {}

    public func stream(
        messages: [Message],
        contextFiles: [LoadedFile]
    ) async throws -> AsyncThrowingStream<StreamChunk<ModelResponse>, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try Task.checkCancellation()
                    let tokens = ["Stub ", "response"]
                    for token in tokens {
                        try Task.checkCancellation()
                        try await Task.sleep(nanoseconds: 5_000_000) // small delay to mimic streaming
                        continuation.yield(.token(token))
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable reason in
                task.cancel()
                if case .cancelled = reason {
                    continuation.finish(throwing: CancellationError())
                }
            }
        }
    }
}

