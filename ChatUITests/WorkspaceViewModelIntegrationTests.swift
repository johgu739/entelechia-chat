import XCTest
@testable import ChatUI
import CoreEngine
import UIConnections

private final class StubWorkspaceEngine: WorkspaceEngine {
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

    func select(path: String?) async throws -> WorkspaceSnapshot {
        let did = snapshot.descriptorPaths.first?.key
        snapshot = WorkspaceSnapshot(
            rootPath: snapshot.rootPath,
            selectedPath: path,
            lastPersistedSelection: path,
            selectedDescriptorID: did,
            lastPersistedDescriptorID: did,
            contextPreferences: snapshot.contextPreferences,
            descriptorPaths: snapshot.descriptorPaths,
            contextInclusions: snapshot.contextInclusions,
            descriptors: snapshot.descriptors
        )
        continuation.yield(WorkspaceUpdate(snapshot: snapshot, projection: projection, error: nil))
        return snapshot
    }

    func contextPreferences() async throws -> WorkspaceSnapshot { snapshot }

    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot {
        var prefs = snapshot.contextPreferences
        if included {
            prefs.includedPaths.insert(path)
            prefs.excludedPaths.remove(path)
        } else {
            prefs.includedPaths.remove(path)
            prefs.excludedPaths.insert(path)
        }
        let did = snapshot.descriptorPaths.first?.key
        let updatedInclusions = [did: included ? ContextInclusionState.included : .excluded].compactMapValues { $0 }
        snapshot = WorkspaceSnapshot(
            rootPath: snapshot.rootPath,
            selectedPath: snapshot.selectedPath,
            lastPersistedSelection: snapshot.lastPersistedSelection,
            selectedDescriptorID: snapshot.selectedDescriptorID,
            lastPersistedDescriptorID: snapshot.lastPersistedDescriptorID,
            contextPreferences: prefs,
            descriptorPaths: snapshot.descriptorPaths,
            contextInclusions: updatedInclusions,
            descriptors: snapshot.descriptors
        )
        continuation.yield(WorkspaceUpdate(snapshot: snapshot, projection: projection, error: nil))
        return snapshot
    }

    func treeProjection() async -> WorkspaceTreeProjection? { projection }
    func updates() -> AsyncStream<WorkspaceUpdate> { stream }
}

private final class StubConversationEngine: ConversationStreaming {
    func conversation(for url: URL) async -> Conversation? { Conversation(contextFilePaths: [url.path]) }
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? { Conversation(contextDescriptorIDs: ids) }
    func ensureConversation(for url: URL) async throws -> Conversation { Conversation(contextFilePaths: [url.path]) }
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation {
        Conversation(contextDescriptorIDs: ids, contextFilePaths: ids.compactMap { pathResolver($0) })
    }
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {}
    func sendMessage(_ text: String, in conversation: Conversation, context: ConversationContextRequest?, onStream: ((ConversationDelta) -> Void)?) async throws -> (Conversation, ContextBuildResult) {
        (conversation, ContextBuilder().build(from: []))
    }
}

private struct StubTodosLoader: ProjectTodosLoading {
    func loadTodos(for root: URL) throws -> ProjectTodos { .empty }
}

final class WorkspaceViewModelIntegrationTests: XCTestCase {

    func testWorkspaceViewModelReceivesUpdatesAndSelection() async throws {
        let workspaceEngine = StubWorkspaceEngine()
        let conversationEngine = StubConversationEngine()
        let vm = WorkspaceViewModel(
            workspaceEngine: workspaceEngine,
            conversationEngine: conversationEngine,
            projectTodosLoader: StubTodosLoader(),
            alertCenter: AlertCenter()
        )

        // Wait for initial update
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.rootDirectory?.path, "/root")
        XCTAssertNil(vm.selectedDescriptorID)

        // Select descriptor ID
        let did = vm.workspaceSnapshot.descriptorPaths.first?.key
        vm.setSelectedDescriptorID(did)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.selectedDescriptorID, did)
        XCTAssertEqual(vm.selectedNode?.path.path, "/root/file.swift")

        // Include in context and expect inclusion state to reflect
        if let url = vm.selectedNode?.path {
            vm.setContextInclusion(true, for: url)
            try await Task.sleep(nanoseconds: 50_000_000)
            if let did = did {
                XCTAssertEqual(vm.workspaceSnapshot.contextInclusions[did], .included)
            }
        }
    }
}

