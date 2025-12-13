import Foundation
import AppCoreEngine

/// Public adapter from domain ConversationEngineLive to ConversationStreaming protocol.
/// Allows AppComposition to adapt domain engines for use with CodexQueryService.
@MainActor
public final class ConversationEngineBox<Client: CodexClient, Persistence: ConversationPersistenceDriver>: @unchecked Sendable, ConversationStreaming
where Client.MessageType == Message,
      Client.ContextFileType == LoadedFile,
      Client.OutputPayload == ModelResponse,
      Persistence.ConversationType == Conversation {
    private let adapter: ConversationEngineAdapter<Client, Persistence>
    
    public init(engine: ConversationEngineLive<Client, Persistence>) {
        self.adapter = ConversationEngineAdapter(engine: engine)
    }
    
    public func conversation(for url: URL) async -> Conversation? {
        await adapter.conversation(for: url)
    }
    
    public func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? {
        await adapter.conversation(forDescriptorIDs: ids)
    }
    
    public func ensureConversation(for url: URL) async throws -> Conversation {
        try await adapter.ensureConversation(for: url)
    }
    
    public func ensureConversation(
        forDescriptorIDs ids: [FileID],
        pathResolver: (FileID) -> String?
    ) async throws -> Conversation {
        try await adapter.ensureConversation(forDescriptorIDs: ids, pathResolver: pathResolver)
    }
    
    public func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {
        try await adapter.updateContextDescriptors(for: conversationID, descriptorIDs: descriptorIDs)
    }
    
    public func sendMessage(
        _ text: String,
        in conversation: Conversation,
        context: ConversationContextRequest?,
        onStream: ((ConversationDelta) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult) {
        try await adapter.sendMessage(text, in: conversation, context: context, onStream: onStream)
    }
}

