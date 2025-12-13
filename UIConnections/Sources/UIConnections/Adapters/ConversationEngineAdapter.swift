import Foundation
import AppCoreEngine

/// Adapter from domain ConversationEngineLive to internal ConversationStreaming protocol.
/// This allows WorkspaceCoordinator to use the internal protocol while accepting domain engines from factories.
@MainActor
internal final class ConversationEngineAdapter<Client: CodexClient, Persistence: ConversationPersistenceDriver>: ConversationStreaming
where Client.MessageType == Message,
      Client.ContextFileType == LoadedFile,
      Client.OutputPayload == ModelResponse,
      Persistence.ConversationType == Conversation {
    private let engine: ConversationEngineLive<Client, Persistence>
    
    internal init(engine: ConversationEngineLive<Client, Persistence>) {
        self.engine = engine
    }
    
    internal func conversation(for url: URL) async -> Conversation? {
        await engine.conversation(for: url)
    }
    
    internal func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? {
        await engine.conversation(forDescriptorIDs: ids)
    }
    
    internal func ensureConversation(for url: URL) async throws -> Conversation {
        try await engine.ensureConversation(for: url)
    }
    
    internal func ensureConversation(
        forDescriptorIDs ids: [FileID],
        pathResolver: (FileID) -> String?
    ) async throws -> Conversation {
        try await engine.ensureConversation(forDescriptorIDs: ids, pathResolver: pathResolver)
    }
    
    internal func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {
        try await engine.updateContextDescriptors(for: conversationID, descriptorIDs: descriptorIDs)
    }
    
    internal func sendMessage(
        _ text: String,
        in conversation: Conversation,
        context: ConversationContextRequest?,
        onStream: ((ConversationDelta) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult) {
        try await engine.sendMessage(text, in: conversation, context: context, onStream: onStream)
    }
}
