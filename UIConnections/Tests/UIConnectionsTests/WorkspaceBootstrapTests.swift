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

/// Tests for workspace opening and file tree population.
/// Guarantees basic ability to open a workspace and populate the file tree.
@MainActor
final class WorkspaceBootstrapTests: XCTestCase {
    
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
    
    // MARK: - Test A: Opening a workspace populates rootFileNode
    
    func testOpeningWorkspacePopulatesRootFileNode() async throws {
        // Create a test workspace with files
        let file1 = tempDir.appendingPathComponent("file1.swift")
        let file2 = tempDir.appendingPathComponent("file2.swift")
        let subdir = tempDir.appendingPathComponent("Subdir")
        
        try "// file1".write(to: file1, atomically: true, encoding: .utf8)
        try "// file2".write(to: file2, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        
        let subfile = subdir.appendingPathComponent("subfile.swift")
        try "// subfile".write(to: subfile, atomically: true, encoding: .utf8)
        
        // Create engine with real implementation
        let engine = makeRealEngine()
        
        let vm = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: ConversationEngineStub(),
            projectTodosLoader: StubTodosLoader(),
            codexService: NullCodexQuerying()
        )
        
        // Open workspace explicitly (no lifecycle modifiers)
        await vm.openWorkspace(at: tempDir)
        
        // Verify rootFileNode is populated
        XCTAssertNotNil(vm.rootFileNode, "rootFileNode should be populated after opening workspace")
        XCTAssertNotNil(vm.rootFileNode?.children, "rootFileNode should have children")
        XCTAssertGreaterThan(vm.rootFileNode?.children?.count ?? 0, 0, "rootFileNode should have at least one child")
        
        // Verify file tree structure
        let children = vm.rootFileNode?.children ?? []
        let fileNames = Set(children.map { $0.name })
        XCTAssertTrue(fileNames.contains("file1.swift") || fileNames.contains("file2.swift") || fileNames.contains("Subdir"),
                     "File tree should contain created files")
    }
    
    func testRootFileNodeReflectsWorkspaceStructure() async throws {
        // Create nested structure
        let level1 = tempDir.appendingPathComponent("Level1")
        let level2 = level1.appendingPathComponent("Level2")
        try FileManager.default.createDirectory(at: level2, withIntermediateDirectories: true)
        
        let deepFile = level2.appendingPathComponent("deep.swift")
        try "// deep".write(to: deepFile, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeViewModel(engine: engine)
        
        await vm.openWorkspace(at: tempDir)
        
        guard let rootNode = vm.rootFileNode else {
            XCTFail("rootFileNode should exist")
            return
        }
        
        // Verify we can navigate the tree
        let level1Node = rootNode.children?.first { $0.name == "Level1" }
        XCTAssertNotNil(level1Node, "Should find Level1 directory")
        XCTAssertTrue(level1Node?.isDirectory == true, "Level1 should be a directory")
        
        let level2Node = level1Node?.children?.first { $0.name == "Level2" }
        XCTAssertNotNil(level2Node, "Should find Level2 directory")
        
        let deepFileNode = level2Node?.children?.first { $0.name == "deep.swift" }
        XCTAssertNotNil(deepFileNode, "Should find deep.swift file")
        XCTAssertFalse(deepFileNode?.isDirectory == true, "deep.swift should be a file")
    }
    
    func testOpeningEmptyWorkspace() async throws {
        // Empty directory
        let engine = makeRealEngine()
        let vm = makeViewModel(engine: engine)
        
        await vm.openWorkspace(at: tempDir)
        
        // rootFileNode should exist but may be empty or have no children
        // The exact behavior depends on implementation, but it shouldn't crash
        XCTAssertNotNil(vm.rootFileNode, "rootFileNode should exist even for empty workspace")
    }
    
    func testRootDirectoryIsSetAfterOpening() async throws {
        let file = tempDir.appendingPathComponent("test.swift")
        try "// test".write(to: file, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeViewModel(engine: engine)
        
        XCTAssertNil(vm.rootDirectory, "rootDirectory should be nil before opening")
        
        await vm.openWorkspace(at: tempDir)
        
        XCTAssertNotNil(vm.rootDirectory, "rootDirectory should be set after opening")
        XCTAssertEqual(vm.rootDirectory?.path, tempDir.path, "rootDirectory should match opened path")
    }
    
    // MARK: - Test B: File selection resolves descriptor and emits state
    
    func testSelectingFileResolvesDescriptor() async throws {
        let file = tempDir.appendingPathComponent("selected.swift")
        try "// selected".write(to: file, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeViewModel(engine: engine)
        
        await vm.openWorkspace(at: tempDir)
        
        // Wait a bit for tree to populate
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Select the file
        await vm.selectPath(file)
        
        // Verify selection state
        XCTAssertNotNil(vm.selectedDescriptorID, "selectedDescriptorID should be set after selection")
        XCTAssertNotNil(vm.selectedNode, "selectedNode should be set after selection")
        XCTAssertEqual(vm.selectedNode?.path.path, file.path, "selectedNode should match selected file")
    }
    
    func testSelectionStateIsClearedWhenWorkspaceChanges() async throws {
        let file1 = tempDir.appendingPathComponent("file1.swift")
        try "// file1".write(to: file1, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeViewModel(engine: engine)
        
        await vm.openWorkspace(at: tempDir)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        await vm.selectPath(file1)
        XCTAssertNotNil(vm.selectedNode)
        
        // Open a different workspace (create new temp dir)
        let newTempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: newTempDir, withIntermediateDirectories: true)
        
        await vm.openWorkspace(at: newTempDir)
        
        // Selection should be cleared
        XCTAssertNil(vm.selectedNode, "selectedNode should be cleared when workspace changes")
        XCTAssertNil(vm.selectedDescriptorID, "selectedDescriptorID should be cleared when workspace changes")
    }
    
    // MARK: - Test C: No lifecycle modifiers required
    
    func testBootstrapDoesNotRequireLifecycleModifiers() async throws {
        // This test verifies that workspace opening works without any SwiftUI lifecycle
        let file = tempDir.appendingPathComponent("test.swift")
        try "// test".write(to: file, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeViewModel(engine: engine)
        
        // Direct call - no .task, no .onAppear
        await vm.openWorkspace(at: tempDir)
        
        // Verify it worked
        XCTAssertNotNil(vm.rootFileNode)
        XCTAssertNotNil(vm.rootDirectory)
        
        // Verify no async work is pending that would require lifecycle
        // (This is a sanity check - if we got here, it worked)
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
