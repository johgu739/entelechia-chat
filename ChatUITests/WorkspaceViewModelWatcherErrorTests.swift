import XCTest
@testable import ChatUI
import AppComposition
@testable import AppAdapters

final class WorkspaceViewModelWatcherErrorTests: XCTestCase {
    func testWatcherErrorSurfacesAndClears() async throws {
        let home = try TemporaryHome()
        defer { home.restore() }

        let streamEngine = StreamWorkspaceEngine()
        let conversationEngine = StubConversationEngine()

        let vm = await MainActor.run {
            WorkspaceViewModel(
                workspaceEngine: streamEngine,
                conversationEngine: conversationEngine,
                projectTodosLoader: StubTodosLoader(),
                alertCenter: nil
            )
        }

        // Send error update
        streamEngine.send(
            WorkspaceUpdate(snapshot: .empty, projection: nil, error: .watcherUnavailable)
        )
        try await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run {
            XCTAssertEqual(vm.watcherError, "Workspace watcher stopped (root missing or inaccessible).")
        }

        // Send healthy update to clear
        streamEngine.send(
            WorkspaceUpdate(snapshot: .empty, projection: nil, error: nil)
        )
        try await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run {
            XCTAssertNil(vm.watcherError)
        }
    }
}

private final class StreamWorkspaceEngine: WorkspaceEngine, @unchecked Sendable {
    private var continuation: AsyncStream<WorkspaceUpdate>.Continuation?
    private let stream: AsyncStream<WorkspaceUpdate>

    init() {
        var cont: AsyncStream<WorkspaceUpdate>.Continuation!
        self.stream = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    func send(_ update: WorkspaceUpdate) {
        continuation?.yield(update)
    }

    func openWorkspace(rootPath: String) async throws -> WorkspaceSnapshot { .empty }
    func snapshot() async -> WorkspaceSnapshot { .empty }
    func refresh() async throws -> WorkspaceSnapshot { .empty }
    func select(path: String?) async throws -> WorkspaceSnapshot { .empty }
    func contextPreferences() async throws -> WorkspaceSnapshot { .empty }
    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot { .empty }
    func treeProjection() async -> WorkspaceTreeProjection? { nil }
    func updates() -> AsyncStream<WorkspaceUpdate> { stream }
}

private final class StubConversationEngine: ConversationStreaming {
    func conversation(for url: URL) async -> Conversation? { nil }
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? { nil }
    func ensureConversation(for url: URL) async throws -> Conversation { Conversation(title: "test") }
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation { Conversation(title: "test") }
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {}
    func sendMessage(_ text: String, in conversation: Conversation, context: ConversationContextRequest?, onStream: ((ConversationDelta) -> Void)?) async throws -> (Conversation, ContextBuildResult) {
        (conversation, ContextBuilder().build(from: []))
    }
}

private struct StubTodosLoader: ProjectTodosLoading {
    func loadTodos(for root: URL) throws -> ProjectTodos { .empty }
}

