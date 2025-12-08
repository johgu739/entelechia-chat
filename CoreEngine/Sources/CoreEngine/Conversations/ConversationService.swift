import Foundation

public enum ConversationServiceError: LocalizedError, Sendable {
    case emptyMessage

    public var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Message cannot be empty"
        }
    }
}

/// Compatibility wrapper that now delegates to the canonical ConversationEngineLive.
@available(*, deprecated, message: "Use ConversationEngineLive instead; this wrapper will be removed.")
public final class ConversationService<Client: CodexClient, Persistence: ConversationPersistenceDriver>: Sendable
where Client.MessageType == Message,
      Client.ContextFileType == LoadedFile,
      Client.OutputPayload == ModelResponse,
      Persistence.ConversationType == Conversation {

    private let engine: ConversationEngineLive<Client, Persistence>
    private let contextBuilder: ContextBuilder

    public init(
        assistant: Client,
        persistence: Persistence,
        fileLoader: FileContentLoading,
        contextBuilder: ContextBuilder = ContextBuilder()
    ) {
        self.contextBuilder = contextBuilder
        self.engine = ConversationEngineLive(
            client: assistant,
            persistence: persistence,
            fileLoader: fileLoader,
            contextBuilder: contextBuilder
        )
    }

    /// Send a message with optional context files; returns updated conversation and context result.
    public func sendMessage(
        _ text: String,
        in conversation: Conversation,
        contextURLs: [URL] = [],
        onStreamEvent: ((StreamChunk<ModelResponse>) -> Void)? = nil
    ) async throws -> (Conversation, ContextBuildResult) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversationServiceError.emptyMessage
        }

        var lastAggregate = ""
        var emittedDone = false
        let (updated, contextResult) = try await engine.sendMessage(
            text,
            in: conversation,
            context: ConversationContextRequest(
                contextFileURLs: contextURLs,
                budget: contextBuilder.budgetConfig
            ),
            onStream: { delta in
                switch delta {
                case .context:
                    // Keep stream contract focused on model payloads for compatibility.
                    break
                case .assistantStreaming(let aggregate):
                    lastAggregate = aggregate
                    onStreamEvent?(.token(aggregate))
                case .assistantCommitted(let message):
                    onStreamEvent?(.output(ModelResponse(content: message.text)))
                    onStreamEvent?(.done)
                    emittedDone = true
                }
            }
        )

        if !emittedDone && !lastAggregate.isEmpty {
            onStreamEvent?(.token(lastAggregate))
            onStreamEvent?(.done)
        } else if !emittedDone {
            onStreamEvent?(.done)
        }

        return (updated, contextResult)
    }

    /// Read-only convenience: find a conversation for URL from persistence.
    public func conversation(for url: URL) async -> Conversation? {
        await engine.conversation(for: url)
    }

    public func ensureConversation(for url: URL) async throws -> Conversation {
        try await engine.ensureConversation(for: url)
    }
}

