import XCTest
import AppCoreEngine
@testable import UIConnections

private final class StubWorkspaceEngine: WorkspaceEngine, @unchecked Sendable {
    private var snapshot: WorkspaceSnapshot
    private let projection: WorkspaceTreeProjection
    private let stream: AsyncStream<WorkspaceUpdate>
    private let continuation: AsyncStream<WorkspaceUpdate>.Continuation

    init() {
        let fileID = FileID()
        snapshot = WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: nil,
            lastPersistedSelection: nil,
            selectedDescriptorID: nil,
            lastPersistedDescriptorID: nil,
            contextPreferences: .empty,
            descriptorPaths: [fileID: "/root/file.swift"],
            contextInclusions: [fileID: .neutral],
            descriptors: [FileDescriptor(id: fileID, name: "file.swift", type: .file)]
        )
        projection = WorkspaceTreeProjection(
            id: fileID,
            name: "file.swift",
            path: "/root/file.swift",
            isDirectory: false,
            children: []
        )

        var cont: AsyncStream<WorkspaceUpdate>.Continuation!
        stream = AsyncStream { cont = $0 }
        continuation = cont
        continuation.yield(WorkspaceUpdate(snapshot: snapshot, projection: projection, error: nil))
    }

    func openWorkspace(rootPath: String) async throws -> WorkspaceSnapshot { snapshot }
    func snapshot() async -> WorkspaceSnapshot { snapshot }
    func refresh() async throws -> WorkspaceSnapshot { snapshot }
    func select(path: String?) async throws -> WorkspaceSnapshot { snapshot }
    func contextPreferences() async throws -> WorkspaceSnapshot { snapshot }
    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot { snapshot }
    func treeProjection() async -> WorkspaceTreeProjection? { projection }
    func updates() -> AsyncStream<WorkspaceUpdate> { stream }

    func pushError(_ error: WorkspaceUpdateError) {
        continuation.yield(WorkspaceUpdate(snapshot: snapshot, projection: projection, error: error))
    }
}

private final class StubTodosLoader: ProjectTodosLoading, @unchecked Sendable {
    private let todos: ProjectTodos
    
    init(todos: ProjectTodos = .empty) {
        self.todos = todos
    }
    
    func loadTodos(for root: URL) throws -> ProjectTodos { todos }
}

@MainActor
final class WorkspaceViewModelIntegrationTests: XCTestCase {
    func testWatcherErrorMapsToNotice() async throws {
        let engine = StubWorkspaceEngine()
        let vm = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: ConversationEngineStub(),
            projectTodosLoader: StubTodosLoader(),
            codexService: CodexServiceStub(),
            alertCenter: AlertCenter()
        )
        engine.pushError(.watcherUnavailable)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.watcherError, "Workspace watcher stopped (root missing or inaccessible).")
    }
}

private final class CodexServiceStub: CodexQuerying {
    func askAboutWorkspaceNode(scope: WorkspaceScope, question: String, onStream: ((String) -> Void)?) async throws -> CodexAnswer {
        CodexAnswer(text: "", context: ContextBuildResult(attachments: [], truncatedFiles: [], excludedFiles: [], totalBytes: 0, totalTokens: 0, budget: .default, encodedSegments: []))
    }
}

private final class ConversationEngineStub: ConversationStreaming {
    func conversation(for url: URL) async -> Conversation? { nil }
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? { nil }
    func ensureConversation(for url: URL) async throws -> Conversation { Conversation(contextFilePaths: [url.path]) }
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation { Conversation(contextFilePaths: []) }
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {}
    func sendMessage(_ text: String, in conversation: Conversation, context: ConversationContextRequest?, onStream: ((ConversationDelta) -> Void)?) async throws -> (Conversation, ContextBuildResult) {
        (conversation, ContextBuildResult(attachments: [], truncatedFiles: [], excludedFiles: [], totalBytes: 0, totalTokens: 0, budget: .default, encodedSegments: []))
    }
}


