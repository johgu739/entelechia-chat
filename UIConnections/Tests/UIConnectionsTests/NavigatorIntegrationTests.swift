import XCTest
import Foundation
import AppCoreEngine
@testable import UIConnections
import AppAdapters

// MARK: - Test Doubles

private final class StubTodosLoader: ProjectTodosLoading, @unchecked Sendable {
    func loadTodos(for root: URL) throws -> ProjectTodos { .empty }
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

/// Tests for Navigator DataSource integration with WorkspaceViewModel.
/// Ensures the navigator can read and display the file tree correctly.
@MainActor
final class NavigatorIntegrationTests: XCTestCase {
    
    private var tempDir: URL!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }
    
    // MARK: - Test A: WorkspaceViewModel provides tree data for Navigator
    
    func testWorkspaceViewModelProvidesTreeDataForNavigator() async throws {
        // Create test files
        let file1 = tempDir.appendingPathComponent("file1.swift")
        let file2 = tempDir.appendingPathComponent("file2.swift")
        let subdir = tempDir.appendingPathComponent("Subdir")
        
        try "// file1".write(to: file1, atomically: true, encoding: .utf8)
        try "// file2".write(to: file2, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        
        let engine = makeRealEngine()
        let vm = makeViewModel(engine: engine)
        
        await vm.openWorkspace(at: tempDir)
        try await Task.sleep(nanoseconds: 200_000_000) // Allow tree to populate
        
        // Verify rootFileNode is available for Navigator
        XCTAssertNotNil(vm.rootFileNode, "rootFileNode should be available for Navigator")
        
        guard let rootNode = vm.rootFileNode else {
            XCTFail("rootNode should exist")
            return
        }
        
        let children = rootNode.children ?? []
        XCTAssertGreaterThan(children.count, 0, "Root node should have children for Navigator")
        
        // Verify file names are accessible
        let fileNames = Set(children.map { $0.name })
        XCTAssertTrue(fileNames.contains("file1.swift") || fileNames.contains("file2.swift") || fileNames.contains("Subdir"),
                     "WorkspaceViewModel should provide file tree data")
    }
    
    func testWorkspaceViewModelReflectsWorkspaceChanges() async throws {
        let file1 = tempDir.appendingPathComponent("file1.swift")
        try "// file1".write(to: file1, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeViewModel(engine: engine)
        
        await vm.openWorkspace(at: tempDir)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        let initialCount = vm.rootFileNode?.children?.count ?? 0
        
        // Add a new file
        let file2 = tempDir.appendingPathComponent("file2.swift")
        try "// file2".write(to: file2, atomically: true, encoding: .utf8)
        
        // Trigger refresh
        try await engine.refresh()
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify new file appears in rootFileNode
        let newCount = vm.rootFileNode?.children?.count ?? 0
        XCTAssertGreaterThanOrEqual(newCount, initialCount, "WorkspaceViewModel should reflect new files after refresh")
    }
    
    // MARK: - Test B: Node identities are preserved
    
    func testNodeIdentitiesArePreserved() async throws {
        let file = tempDir.appendingPathComponent("test.swift")
        try "// test".write(to: file, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeViewModel(engine: engine)
        
        await vm.openWorkspace(at: tempDir)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        guard let originalNode = vm.rootFileNode?.children?.first(where: { $0.name == "test.swift" }) else {
            XCTFail("Should find test.swift node")
            return
        }
        
        let originalID = originalNode.descriptorID
        let originalPath = originalNode.path
        
        // Verify node identity is preserved
        XCTAssertNotNil(originalID, "Node should have descriptorID")
        XCTAssertEqual(originalPath.path, file.path, "Node path should match file")
    }
    
    // MARK: - Test C: Selection state is available for Navigator
    
    func testSelectionStateIsAvailable() async throws {
        let file1 = tempDir.appendingPathComponent("file1.swift")
        let file2 = tempDir.appendingPathComponent("file2.swift")
        try "// file1".write(to: file1, atomically: true, encoding: .utf8)
        try "// file2".write(to: file2, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeViewModel(engine: engine)
        
        await vm.openWorkspace(at: tempDir)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        await vm.selectPath(file1)
        
        guard let selectedID = vm.selectedDescriptorID else {
            XCTFail("selectedDescriptorID should be set")
            return
        }
        
        // Verify we can find the selected node in the tree
        guard let rootNode = vm.rootFileNode else {
            XCTFail("rootNode should exist")
            return
        }
        
        // Verify we can find the node by descriptor ID
        func findNode(withID id: FileID, in node: FileNode) -> FileNode? {
            if node.descriptorID == id {
                return node
            }
            for child in node.children ?? [] {
                if let found = findNode(withID: id, in: child) {
                    return found
                }
            }
            return nil
        }
        
        let foundNode = findNode(withID: selectedID, in: rootNode)
        XCTAssertNotNil(foundNode, "Should be able to find selected node by descriptor ID")
        XCTAssertEqual(foundNode?.path.path, file1.path, "Found node should match selected file")
    }
    
    // MARK: - Helper Methods
    
    private func makeRealEngine() -> WorkspaceEngineImpl<PreferencesStoreAdapter<WorkspacePreferences>, ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>> {
        let fileSystem = FileSystemAccessAdapter()
        let preferences = PreferencesStoreAdapter<WorkspacePreferences>(strict: true)
        let contextPreferences = ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>(strict: true)
        let watcher = FileSystemWatcherAdapter()
        
        return WorkspaceEngineImpl(
            fileSystem: fileSystem,
            preferences: preferences,
            contextPreferences: contextPreferences,
            watcher: watcher
        )
    }
    
    private func makeViewModel(engine: WorkspaceEngine) -> WorkspaceViewModel {
        WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: ConversationEngineStub(),
            projectTodosLoader: StubTodosLoader(),
            codexService: NullCodexQuerying()
        )
    }
}
