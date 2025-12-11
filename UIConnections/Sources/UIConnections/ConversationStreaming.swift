import Foundation
import AppCoreEngine

/// UI-facing, non-generic surface for conversation orchestration.
public protocol ConversationStreaming: Sendable {
    func conversation(for url: URL) async -> Conversation?
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation?
    func ensureConversation(for url: URL) async throws -> Conversation
    func ensureConversation(
        forDescriptorIDs ids: [FileID],
        pathResolver: (FileID) -> String?
    ) async throws -> Conversation
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws
    func sendMessage(
        _ text: String,
        in conversation: Conversation,
        context: ConversationContextRequest?,
        onStream: ((ConversationDelta) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult)
}

