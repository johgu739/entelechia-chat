import Foundation

/// Production ConversationEngine that enforces invariants, streams Codex responses, and persists reliably.
public final class ConversationEngineLive<Client: CodexClient, Persistence: ConversationPersistenceDriver>: ConversationEngine, @unchecked Sendable
where Client.MessageType == Message,
      Client.ContextFileType == LoadedFile,
      Client.OutputPayload == ModelResponse,
      Persistence.ConversationType == Conversation {

    public typealias ConversationType = Conversation
    public typealias MessageType = Message
    public typealias ContextResult = ContextBuildResult
    public typealias StreamEvent = ConversationStreamEvent

    private let client: Client
    private let persistence: Persistence
    private let fileLoader: FileContentLoading
    private let contextBuilder: ContextBuilder
    private let clock: () -> Date

    public init(
        client: Client,
        persistence: Persistence,
        fileLoader: FileContentLoading,
        contextBuilder: ContextBuilder = ContextBuilder(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.persistence = persistence
        self.fileLoader = fileLoader
        self.contextBuilder = contextBuilder
        self.clock = clock
    }

    public func conversation(for url: URL) -> Conversation? {
        guard let all = try? persistence.loadAllConversations() else { return nil }
        return all.first { $0.contextFilePaths.contains(url.path) }
    }

    public func ensureConversation(for url: URL) async throws -> Conversation {
        if let existing = conversation(for: url) {
            return existing
        }
        let convo = Conversation(contextFilePaths: [url.path])
        try persistence.saveConversation(convo)
        return convo
    }

    public func sendMessage(
        _ text: String,
        in conversation: Conversation,
        contextURL: URL?,
        onStream: ((ConversationStreamEvent) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EngineError.emptyMessage
        }

        var updated = conversation
        updated.messages.append(Message(role: .user, text: trimmed, createdAt: clock()))
        updated.updatedAt = clock()

        // Build context attachments (best-effort)
        var attachments: [LoadedFile] = []
        if let url = contextURL, let content = try? await fileLoader.load(url: url) {
            let file = LoadedFile(
                name: url.lastPathComponent,
                url: url,
                content: content,
                fileTypeIdentifier: url.pathExtension.isEmpty ? nil : url.pathExtension
            )
            attachments.append(file)
        }

        // Context budgeting stays inside Engine
        let contextResult = contextBuilder.build(from: attachments)
        onStream?(.context(contextResult))

        // Stream model output, enforcing deterministic ordering
        var assistantBuffer = ""
        do {
            let stream = try await client.stream(messages: updated.messages, contextFiles: contextResult.attachments)
            for try await chunk in stream {
                onStream?(.model(chunk))
                switch chunk {
                case .token(let token):
                    assistantBuffer += token
                case .output(let payload):
                    assistantBuffer += payload.content
                case .done:
                    break
                }
            }
        } catch {
            throw EngineError.streamingFailed
        }

        // Persist assistant reply
        if !assistantBuffer.isEmpty {
            updated.messages.append(
                Message(role: .assistant, text: assistantBuffer, createdAt: clock())
            )
            updated.updatedAt = clock()
        }

        do {
            try persistence.saveConversation(updated)
        } catch {
            throw EngineError.persistenceFailed
        }
        return (updated, contextResult)
    }
}

