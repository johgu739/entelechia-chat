import Foundation

/// Temporary stub implementation to satisfy wiring while adapters migrate.
public final class ConversationEngineStub<Client: CodexClient, Persistence: ConversationPersistenceDriver>: ConversationEngine, @unchecked Sendable
where Client.MessageType == Message,
      Client.ContextFileType == LoadedFile,
      Client.OutputPayload == ModelResponse,
      Persistence.ConversationType == Conversation {

    public typealias ConversationType = Conversation
    public typealias MessageType = Message
    public typealias ContextResult = ContextBuildResult

    private let client: Client
    private let persistence: Persistence
    private let fileLoader: FileContentLoading
    private let contextBuilder: ContextBuilder

    public init(
        client: Client,
        persistence: Persistence,
        fileLoader: FileContentLoading,
        contextBuilder: ContextBuilder = ContextBuilder()
    ) {
        self.client = client
        self.persistence = persistence
        self.fileLoader = fileLoader
        self.contextBuilder = contextBuilder
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
        onStream: ((StreamChunk<ContextBuildResult>) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EngineError.notImplemented // should be emptyMessage error
        }

        var updated = conversation
        updated.messages.append(Message(role: .user, text: text))
        updated.updatedAt = Date()

        // Load context files if a URL is provided (best-effort, serial).
        var attachments: [LoadedFile] = []
        if let url = contextURL {
            if let content = try? await fileLoader.load(url: url) {
                let file = LoadedFile(
                    name: url.lastPathComponent,
                    url: url,
                    content: content,
                    fileTypeIdentifier: url.pathExtension.isEmpty ? nil : url.pathExtension
                )
                attachments.append(file)
            }
        }

        let contextResult = contextBuilder.build(from: attachments)
        onStream?(.output(contextResult))
        onStream?(.done)

        try persistence.saveConversation(updated)
        return (updated, contextResult)
    }
}

