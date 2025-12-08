import XCTest
@testable import ChatUI
@testable import CoreEngine
@testable import AppAdapters

final class WorkspaceViewModelWatcherErrorTests: XCTestCase {
    func testWatcherErrorSurfacesAndClears() async throws {
        let home = try TemporaryHome()
        defer { home.restore() }

        let streamEngine = StreamWorkspaceEngine()
        let conversationEngine = ConversationEngineLive(
            client: AnyCodexClient.stub(),
            persistence: FileStoreConversationPersistence(baseURL: home.url),
            fileLoader: FileContentLoaderAdapter(fileManager: .default)
        )

        let vm = WorkspaceViewModel(
            workspaceEngine: streamEngine,
            conversationEngine: conversationEngine,
            alertCenter: nil
        )

        // Send error update
        streamEngine.send(
            WorkspaceUpdate(snapshot: .empty, projection: nil, error: .watcherUnavailable)
        )
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.watcherError, "Workspace watcher stopped (root missing or inaccessible).")

        // Send healthy update to clear
        streamEngine.send(
            WorkspaceUpdate(snapshot: .empty, projection: nil, error: nil)
        )
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNil(vm.watcherError)
    }
}

private final class StreamWorkspaceEngine: WorkspaceEngine {
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

