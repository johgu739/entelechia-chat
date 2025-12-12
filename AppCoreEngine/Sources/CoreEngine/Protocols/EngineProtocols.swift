import Foundation

/// Conversation orchestration facade.
public protocol ConversationEngine: Sendable {
    associatedtype ConversationType: Sendable
    associatedtype MessageType: Sendable
    associatedtype ContextResult: Sendable
    associatedtype StreamEvent: Sendable

    func conversation(for url: URL) async -> ConversationType?
    func conversation(forDescriptorIDs ids: [FileID]) async -> ConversationType?
    func ensureConversation(for url: URL) async throws -> ConversationType
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> ConversationType
    func sendMessage(
        _ text: String,
        in conversation: ConversationType,
        context: ConversationContextRequest?,
        onStream: ((StreamEvent) -> Void)?
    ) async throws -> (ConversationType, ContextResult)
}

/// Project lifecycle orchestration facade.
public protocol ProjectEngine: Sendable {
    func openProject(at url: URL) throws -> ProjectRepresentation
    func save(_ project: ProjectRepresentation) throws
    func loadAll() throws -> [ProjectRepresentation]
    func validateProject(at url: URL) throws -> ProjectRepresentation
}

/// Workspace navigation/context facade.
public protocol WorkspaceEngine: Sendable {
    func openWorkspace(rootPath: String) async throws -> WorkspaceSnapshot
    func snapshot() async -> WorkspaceSnapshot
    func refresh() async throws -> WorkspaceSnapshot
    func select(path: String?) async throws -> WorkspaceSnapshot
    func contextPreferences() async throws -> WorkspaceSnapshot
    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot
    func treeProjection() async -> WorkspaceTreeProjection?
    func updates() -> AsyncStream<WorkspaceUpdate>
}

/// File mutation planning facade.
/// Power: Descriptive (parses) + Decisional (validates, orders)
public protocol FileMutationPlanning: Sendable {
    func planMutation(_ diffText: String, rootPath: String) throws -> MutationPlan
}

