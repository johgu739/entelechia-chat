import Foundation

/// Temporary stub implementation to satisfy wiring while adapters migrate.
public actor ConversationEngineStub<Client: CodexClient, Persistence: ConversationPersistenceDriver>: ConversationEngine
where Client.MessageType == Message,
      Client.ContextFileType == LoadedFile,
      Client.OutputPayload == ModelResponse,
      Persistence.ConversationType == Conversation {

    public typealias ConversationType = Conversation
    public typealias MessageType = Message
    public typealias ContextResult = ContextBuildResult
    public typealias StreamEvent = StreamChunk<ContextBuildResult>

    private let client: Client
    private let persistence: Persistence
    private let fileLoader: FileContentLoading
    private let contextBuilder: ContextBuilder
    private let contextResolver: ConversationContextResolver

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
        self.contextResolver = ConversationContextResolver(
            fileLoader: fileLoader,
            contextBuilder: contextBuilder
        )
    }

    public func conversation(for url: URL) async -> Conversation? {
        guard let all = try? persistence.loadAllConversations() else { return nil }
        return all.first { $0.contextFilePaths.contains(url.path) }
    }

    public func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? {
        guard let all = try? persistence.loadAllConversations() else { return nil }
        return all.first { convo in
            guard let stored = convo.contextDescriptorIDs else { return false }
            return !ids.filter { stored.contains($0) }.isEmpty
        }
    }

    public func ensureConversation(for url: URL) async throws -> Conversation {
        if let existing = await conversation(for: url) {
            return existing
        }
        let convo = Conversation(contextFilePaths: [url.path])
        try persistence.saveConversation(convo)
        return convo
    }

    public func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation {
        if let existing = await conversation(forDescriptorIDs: ids) {
            return existing
        }
        guard let path = ids.compactMap(pathResolver).first else {
            throw EngineError.invalidSelection("No resolvable path for descriptor IDs")
        }
        let convo = Conversation(contextFilePaths: [path], contextDescriptorIDs: ids)
        try persistence.saveConversation(convo)
        return convo
    }

    public func sendMessage(
        _ text: String,
        in conversation: Conversation,
        context: ConversationContextRequest?,
        onStream: ((StreamChunk<ContextBuildResult>) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EngineError.emptyMessage
        }

        var updated = conversation
        updated.messages.append(Message(role: .user, text: text))
        updated.updatedAt = Date()

        let budget = context?.budget ?? contextBuilder.budgetConfig
        let contextResult = try await contextResolver.resolve(
            from: ConversationContextRequest(
                snapshot: context?.snapshot,
                preferredDescriptorIDs: context?.preferredDescriptorIDs ?? updated.contextDescriptorIDs,
                contextFileURLs: context?.contextFileURLs,
                fallbackContextURL: context?.fallbackContextURL,
                budget: budget
            )
        )
        onStream?(.output(contextResult))
        onStream?(.done)

        try persistence.saveConversation(updated)
        return (updated, contextResult)
    }
}

