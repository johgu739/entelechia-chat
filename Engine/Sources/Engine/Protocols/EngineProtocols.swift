import Foundation

/// Conversation orchestration facade.
public protocol ConversationEngine: Sendable {
    associatedtype ConversationType: Sendable
    associatedtype MessageType: Sendable
    associatedtype ContextResult: Sendable
    associatedtype StreamEvent: Sendable

    func conversation(for url: URL) -> ConversationType?
    func ensureConversation(for url: URL) async throws -> ConversationType
    func sendMessage(
        _ text: String,
        in conversation: ConversationType,
        contextURL: URL?,
        onStream: ((StreamEvent) -> Void)?
    ) async throws -> (ConversationType, ContextResult)
}

/// Project lifecycle orchestration facade.
public protocol ProjectEngine: Sendable {
    func openProject(at url: URL) throws -> ProjectRepresentation
    func save(_ project: ProjectRepresentation) throws
    func loadAll() throws -> [ProjectRepresentation]
}

/// Workspace navigation/context facade.
public protocol WorkspaceEngine: Sendable {
    func openWorkspace(rootPath: String) async throws -> WorkspaceState
    func state() -> WorkspaceState
    func descriptors() -> [FileDescriptor]
    func refresh() async throws -> [FileDescriptor]
    func select(path: String?) async throws -> WorkspaceState
    func contextPreferences() async throws -> WorkspaceContextPreferencesState
    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceContextPreferencesState
}

