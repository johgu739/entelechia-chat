import Foundation
import AppCoreEngine
import AppAdapters

/// UI-facing, non-generic surface for conversation orchestration.
/// This type erases the generic `ConversationEngineLive` so that clients do not
/// depend on concrete persistence or client types.
public protocol ConversationStreaming: Sendable {
    func conversation(for url: URL) async -> Conversation?
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation?
    func ensureConversation(for url: URL) async throws -> Conversation
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws
    func sendMessage(
        _ text: String,
        in conversation: Conversation,
        context: ConversationContextRequest?,
        onStream: ((ConversationDelta) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult)
}

/// Concrete box over the production engine.
public final class ConversationEngineBox: ConversationStreaming {
    private let engine: ConversationEngineLive<AnyCodexClient, FileStoreConversationPersistence>

    public init(engine: ConversationEngineLive<AnyCodexClient, FileStoreConversationPersistence>) {
        self.engine = engine
    }

    public func conversation(for url: URL) async -> Conversation? {
        await engine.conversation(for: url)
    }

    public func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? {
        await engine.conversation(forDescriptorIDs: ids)
    }

    public func ensureConversation(for url: URL) async throws -> Conversation {
        try await engine.ensureConversation(for: url)
    }

    public func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation {
        try await engine.ensureConversation(forDescriptorIDs: ids, pathResolver: pathResolver)
    }

    public func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {
        try await engine.updateContextDescriptors(for: conversationID, descriptorIDs: descriptorIDs)
    }

    public func sendMessage(
        _ text: String,
        in conversation: Conversation,
        context: ConversationContextRequest?,
        onStream: ((ConversationDelta) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult) {
        try await engine.sendMessage(text, in: conversation, context: context, onStream: onStream)
    }
}


