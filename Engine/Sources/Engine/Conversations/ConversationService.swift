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

/// Protocol-driven conversation logic (pure Engine).
public final class ConversationService<Client: CodexClient, Persistence: ConversationPersistenceDriver>: @unchecked Sendable
where Client.MessageType == Message,
      Client.ContextFileType == LoadedFile,
      Client.OutputPayload == ModelResponse,
      Persistence.ConversationType == Conversation {

    private let assistant: Client
    private let persistence: Persistence
    private let fileLoader: FileContentLoading
    private let contextBuilder: ContextBuilder

    public init(
        assistant: Client,
        persistence: Persistence,
        fileLoader: FileContentLoading,
        contextBuilder: ContextBuilder = ContextBuilder()
    ) {
        self.assistant = assistant
        self.persistence = persistence
        self.fileLoader = fileLoader
        self.contextBuilder = contextBuilder
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

        var contextFiles: [LoadedFile] = []
        for url in contextURLs {
            if let content = try? await fileLoader.load(url: url) {
                contextFiles.append(
                    LoadedFile(
                        name: url.lastPathComponent,
                        url: url,
                        content: content,
                        fileTypeIdentifier: url.pathExtension.isEmpty ? nil : url.pathExtension
                    )
                )
            }
        }

        let contextResult = contextBuilder.build(from: contextFiles)

        var updated = conversation
        updated.messages.append(Message(role: .user, text: text))
        updated.updatedAt = Date()

        var streamingText = ""
        var finalMessage: Message?

        do {
            let stream = try await assistant.stream(
                messages: updated.messages,
                contextFiles: contextResult.attachments
            )

            for try await chunk in stream {
                onStreamEvent?(chunk)
                switch chunk {
                case .token(let token):
                    streamingText += token
                case .output(let output):
                    finalMessage = Message(role: .assistant, text: output.content)
                case .done:
                    break
                }
            }
        } catch {
            finalMessage = Message(role: .assistant, text: "Sorry, I encountered an error: \(error.localizedDescription)")
        }

        if let message = finalMessage {
            updated.messages.append(message)
        } else if !streamingText.isEmpty {
            updated.messages.append(Message(role: .assistant, text: streamingText))
        }
        updated.updatedAt = Date()

        try persistence.saveConversation(updated)
        return (updated, contextResult)
    }

    /// Read-only convenience: find a conversation for URL from persistence.
    public func conversation(for url: URL) -> Conversation? {
        guard let all = try? persistence.loadAllConversations() else { return nil }
        return all.first { $0.contextFilePaths.contains(url.path) }
    }
}

