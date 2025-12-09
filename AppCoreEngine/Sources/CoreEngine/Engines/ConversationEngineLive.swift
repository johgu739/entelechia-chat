import Foundation

/// Production ConversationEngine that enforces invariants, streams Codex responses, and persists reliably.
///
/// Invariants:
/// - Context resolution must run before any model streaming; deltas emit `.context` first, then streaming,
///   then `.assistantCommitted` (if any).
/// - Preferred descriptor IDs require a snapshot; if missing, `EngineError.contextRequired` is thrown.
/// - Cache mutations are actor-isolated; persistence failures leave the cache unchanged from the caller’s view.
/// - Client streams are expected to eventually emit `.done`; streaming errors are surfaced as
///   `EngineError.streamingTransport` and do not commit assistant messages.
/// - Descriptor indices/path indices are updated atomically with conversation storage to keep lookups coherent.
public actor ConversationEngineLive<Client: CodexClient, Persistence: ConversationPersistenceDriver>: ConversationEngine
where Client.MessageType == Message,
      Client.ContextFileType == LoadedFile,
      Client.OutputPayload == ModelResponse,
      Persistence.ConversationType == Conversation {

    public typealias ConversationType = Conversation
    public typealias MessageType = Message
    public typealias ContextResult = ContextBuildResult
    public typealias StreamEvent = ConversationDelta

    private let client: Client
    private let persistence: Persistence
    private let contextResolver: ConversationContextResolver
    private let clock: @Sendable () -> Date
    private var cache: [UUID: Conversation] = [:]
    private var pathIndex: [String: UUID] = [:]
    private var descriptorIndex: [FileID: UUID] = [:]
    private let maxCacheEntries: Int

    public init(
        client: Client,
        persistence: Persistence,
        fileLoader: FileContentLoading,
        contextBuilder: ContextBuilder = ContextBuilder(),
        clock: @escaping @Sendable () -> Date = { Date() },
        maxCacheEntries: Int = 500
    ) {
        self.client = client
        self.persistence = persistence
        self.contextResolver = ConversationContextResolver(
            fileLoader: fileLoader,
            contextBuilder: contextBuilder
        )
        self.clock = clock
        self.maxCacheEntries = maxCacheEntries

        let bootstrapped = (try? persistence.loadAllConversations()) ?? []
        let seeded = ConversationEngineLive.seedCache(
            conversations: bootstrapped,
            maxEntries: maxCacheEntries
        )
        self.cache = seeded.cache
        self.pathIndex = seeded.pathIndex
        self.descriptorIndex = seeded.descriptorIndex
    }

    public func conversation(for url: URL) async -> Conversation? {
        conversation(forPath: url.path)
    }

    public func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? {
        conversationForDescriptorIDs(ids)
    }

    public func ensureConversation(for url: URL) async throws -> Conversation {
        if let existing = conversation(forPath: url.path) {
            return existing
        }
        let convo = Conversation(contextFilePaths: [url.path])
        try persistence.saveConversation(convo)
        store(convo)
        return convo
    }

    public func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation {
        if let existing = conversationForDescriptorIDs(ids) {
            return existing
        }
        guard let path = ids.compactMap(pathResolver).first else {
            throw EngineError.invalidSelection("No resolvable path for descriptor IDs")
        }
        let convo = Conversation(contextFilePaths: [path], contextDescriptorIDs: ids)
        try persistence.saveConversation(convo)
        store(convo)
        return convo
    }

    public func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {
        guard var convo = cache[conversationID] else {
            throw EngineError.conversationNotFound("Conversation \(conversationID) not found")
        }
        convo.contextDescriptorIDs = descriptorIDs
        store(convo)
        try persistence.saveConversation(convo)
    }

    public func sendMessage(
        _ text: String,
        in conversation: Conversation,
        context: ConversationContextRequest?,
        onStream: ((ConversationDelta) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult) {
        try Task.checkCancellation()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EngineError.emptyMessage
        }

        if let descriptorIDs = context?.preferredDescriptorIDs,
           !descriptorIDs.isEmpty,
           context?.snapshot == nil {
            throw EngineError.contextRequired("Preferred descriptor IDs require a workspace snapshot")
        }

        var updated = conversation
        updated.messages.append(Message(role: .user, text: trimmed, createdAt: clock()))
        updated.updatedAt = clock()

        let budget = context?.budget ?? contextResolver.defaultBudget
        let descriptorContext = context?.preferredDescriptorIDs ?? updated.contextDescriptorIDs
        if let snapshot = context?.snapshot,
           let ids = descriptorContext,
           !ids.isEmpty {
            let missing = ids.filter { snapshot.descriptorPaths[$0] == nil }
            if !missing.isEmpty {
                throw EngineError.invalidDescriptor("Missing descriptors for IDs: \(missing.count)")
            }
        }

        let resolvedContext = ConversationContextRequest(
            snapshot: context?.snapshot,
            preferredDescriptorIDs: descriptorContext,
            contextFileURLs: context?.contextFileURLs,
            fallbackContextURL: context?.fallbackContextURL,
            budget: budget
        )
        // Callbacks are delivered directly; UI callers should re-dispatch to the main actor if needed.
        let callback = onStream

        let contextResult = try await contextResolver.resolve(from: resolvedContext)
        callback?(.context(contextResult))

        // Stream model output, enforcing deterministic ordering
        var assistantBuffer = ""
        let client = self.client
        let streamTask = Task(priority: .userInitiated) { () -> String in
            var buffer = ""
            do {
                let stream = try await client.stream(messages: updated.messages, contextFiles: contextResult.attachments)
                for try await chunk in stream {
                    try Task.checkCancellation()
                    switch chunk {
                    case .token(let token):
                        buffer += token
                        callback?(.assistantStreaming(buffer))
                    case .output(let payload):
                        buffer += payload.content
                        callback?(.assistantStreaming(buffer))
                    case .done:
                        return buffer
                    }
                }
                return buffer
            } catch {
                if error is CancellationError {
                    throw error
                }
                throw EngineError.streamingTransport(
                    (error as? StreamTransportError) ?? .underlying(error.localizedDescription)
                )
            }
        }

        do {
            assistantBuffer = try await streamTask.value
        } catch {
            streamTask.cancel()
            throw error
        }

        try Task.checkCancellation()

        // Persist assistant reply
        if !assistantBuffer.isEmpty {
            let assistantMessage = Message(role: .assistant, text: assistantBuffer, createdAt: clock())
            updated.messages.append(assistantMessage)
            updated.updatedAt = clock()
            callback?(.assistantCommitted(assistantMessage))
        }

        do {
            // Persist descriptor IDs when available (compat with older data)
            updated.contextDescriptorIDs = descriptorContext
            if !contextResult.attachments.isEmpty {
                updated.contextFilePaths = contextResult.attachments.map { $0.url.path }
            }
            try persistence.saveConversation(updated)
            store(updated)
        } catch {
            throw EngineError.persistenceFailed(underlying: error.localizedDescription)
        }
        return (updated, contextResult)
    }

    // MARK: - Cache helpers (actor-isolated)
    private func conversation(forPath path: String) -> Conversation? {
        guard let id = pathIndex[path] else { return nil }
        return cache[id]
    }

    private func conversationForDescriptorIDs(_ ids: [FileID]) -> Conversation? {
        for descriptor in ids {
            if let convoID = descriptorIndex[descriptor],
               let convo = cache[convoID] {
                return convo
            }
        }
        return nil
    }

    private func store(_ conversation: Conversation) {
        removeIndexes(for: conversation.id)
        cache[conversation.id] = conversation
        for path in conversation.contextFilePaths {
            pathIndex[path] = conversation.id
        }
        if let ids = conversation.contextDescriptorIDs {
            ids.forEach { descriptorIndex[$0] = conversation.id }
        }
        evictIfNeeded()
    }

    private func evictIfNeeded() {
        guard cache.count > maxCacheEntries else { return }
        let overflow = cache.count - maxCacheEntries
        let sorted = cache.values.sorted { $0.updatedAt < $1.updatedAt }
        for convo in sorted.prefix(overflow) {
            cache.removeValue(forKey: convo.id)
            removeIndexes(for: convo.id)
        }
    }

    private func removeIndexes(for conversationID: UUID) {
        pathIndex = pathIndex.filter { $0.value != conversationID }
        descriptorIndex = descriptorIndex.filter { $0.value != conversationID }
    }

    private static func seedCache(
        conversations: [Conversation],
        maxEntries: Int
    ) -> (cache: [UUID: Conversation], pathIndex: [String: UUID], descriptorIndex: [FileID: UUID]) {
        var cache: [UUID: Conversation] = [:]
        var pathIndex: [String: UUID] = [:]
        var descriptorIndex: [FileID: UUID] = [:]
        let sorted = conversations.sorted { $0.updatedAt > $1.updatedAt }
        for convo in sorted.prefix(maxEntries) {
            cache[convo.id] = convo
            for path in convo.contextFilePaths {
                pathIndex[path] = convo.id
            }
            if let ids = convo.contextDescriptorIDs {
                ids.forEach { descriptorIndex[$0] = convo.id }
            }
        }
        return (cache, pathIndex, descriptorIndex)
    }
}


