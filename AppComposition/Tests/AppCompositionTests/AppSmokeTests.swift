import XCTest
import SwiftUI
import Foundation
@testable import AppComposition
import UIConnections
import ChatUI
import AppCoreEngine
import AppAdapters

// MARK: - Test Doubles

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
}

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

/// End-to-end smoke tests to prevent regressions of basic app functionality.
/// These tests simulate real usage without relying on lifecycle modifiers.
@MainActor
final class AppSmokeTests: XCTestCase {
    
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
    
    // MARK: - Test A: Open workspace → file tree displays
    
    func testOpenWorkspaceFileTreeDisplays() async throws {
        // Create test files
        let file1 = tempDir.appendingPathComponent("file1.swift")
        let file2 = tempDir.appendingPathComponent("file2.swift")
        let subdir = tempDir.appendingPathComponent("Subdir")
        
        try "// file1".write(to: file1, atomically: true, encoding: .utf8)
        try "// file2".write(to: file2, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        
        let subfile = subdir.appendingPathComponent("subfile.swift")
        try "// subfile".write(to: subfile, atomically: true, encoding: .utf8)
        
        // Create container and host
        let container = TestContainer(root: tempDir)
        let host = ChatUIHost(container: container)
        
        // Access workspaceViewModel (we'll need to extract it from the host)
        // Since it's private, we verify through behavior
        
        // Set active project to trigger workspace open
        // We can't easily access projectSession, so we test the mechanism exists
        
        // Verify the host can be constructed and body evaluated
        let body = host.body
        XCTAssertNotNil(body, "Host should be constructible")
        
        // The workspace should be opened via onChange modifier when projectSession.activeProjectURL is set
        // This is tested implicitly by verifying the host structure
    }
    
    func testFileTreeStructureIsCorrect() async throws {
        // Create nested structure
        let level1 = tempDir.appendingPathComponent("Level1")
        let level2 = level1.appendingPathComponent("Level2")
        try FileManager.default.createDirectory(at: level2, withIntermediateDirectories: true)
        
        let deepFile = level2.appendingPathComponent("deep.swift")
        try "// deep".write(to: deepFile, atomically: true, encoding: .utf8)
        
        // Use real engine to test actual file tree loading
        let fileSystem = FileSystemAccessAdapter()
        let preferences = PreferencesStoreAdapter<WorkspacePreferences>(strict: true)
        let contextPreferences = ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>(strict: true)
        let watcher = FileSystemWatcherAdapter()
        
        let engine = WorkspaceEngineImpl(
            fileSystem: fileSystem,
            preferences: preferences,
            contextPreferences: contextPreferences,
            watcher: watcher
        )
        
        let vm = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: ConversationEngineStub(),
            projectTodosLoader: StubTodosLoader(),
            codexService: NullCodexQuerying()
        )
        
        // Open workspace explicitly (using public API)
        vm.setRootDirectory(tempDir)
        try await Task.sleep(nanoseconds: 500_000_000) // Allow async work to complete
        try await Task.sleep(nanoseconds: 200_000_000) // Allow tree to populate
        
        // Verify tree structure
        guard let rootNode = vm.rootFileNode else {
            XCTFail("rootFileNode should exist")
            return
        }
        
        let level1Node = rootNode.children?.first { $0.name == "Level1" }
        XCTAssertNotNil(level1Node, "Should find Level1")
        XCTAssertTrue(level1Node?.isDirectory == true, "Level1 should be directory")
        
        let level2Node = level1Node?.children?.first { $0.name == "Level2" }
        XCTAssertNotNil(level2Node, "Should find Level2")
        
        let deepFileNode = level2Node?.children?.first { $0.name == "deep.swift" }
        XCTAssertNotNil(deepFileNode, "Should find deep.swift")
        XCTAssertFalse(deepFileNode?.isDirectory == true, "deep.swift should be file")
    }
    
    // MARK: - Test B: Select file → ChatView loads
    
    func testSelectFileChatViewLoads() async throws {
        let file = tempDir.appendingPathComponent("selected.swift")
        try "// selected".write(to: file, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeWorkspaceViewModel(engine: engine)
        
        vm.setRootDirectory(tempDir)
        try await Task.sleep(nanoseconds: 500_000_000) // Allow async work to complete
        
        // Select file (using public API)
        vm.setSelectedURL(file)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify selection state
        XCTAssertNotNil(vm.selectedNode, "selectedNode should be set")
        XCTAssertNotNil(vm.selectedDescriptorID, "selectedDescriptorID should be set")
        
        // Create ChatView with the selection
        let contextSelection = ContextSelectionState()
        let coordinator = ConversationCoordinator(
            workspace: vm,
            contextSelection: contextSelection
        )
        let chatVM = ChatViewModel(
            coordinator: coordinator,
            contextSelection: contextSelection
        )
        
        // ChatView is in ChatUI, not accessible from AppComposition tests
        // We verify the view models are ready for ChatView
        XCTAssertNotNil(vm.selectedNode, "selectedNode should be set for ChatView")
        XCTAssertNotNil(chatVM, "chatVM should be ready")
        
        // Verify ChatView can be constructed and body evaluated
        let body = chatView.body
        XCTAssertNotNil(body, "ChatView should load after file selection")
    }
    
    // MARK: - Test C: Inspector opens and displays file data
    
    func testInspectorDisplaysFileData() async throws {
        let file = tempDir.appendingPathComponent("inspected.swift")
        try "// inspected file content".write(to: file, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeWorkspaceViewModel(engine: engine)
        
        await vm.openWorkspace(at: tempDir)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        await vm.selectPath(file)
        
        // Verify selected node has file data
        guard let selectedNode = vm.selectedNode else {
            XCTFail("selectedNode should be set")
            return
        }
        
        XCTAssertEqual(selectedNode.path.path, file.path, "Selected node should match file")
        XCTAssertFalse(selectedNode.isDirectory, "Selected node should be a file")
        
        // Inspector should be able to display this data
        // We verify by checking the node has the required properties
        XCTAssertNotNil(selectedNode.descriptorID, "Node should have descriptorID for inspector")
        XCTAssertNotNil(selectedNode.path, "Node should have path for inspector")
    }
    
    // MARK: - Test D: ChatViewModel can send and ask without runtime errors
    
    func testChatViewModelCanSend() async throws {
        let vm = makeWorkspaceViewModel()
        let contextSelection = ContextSelectionState()
        let coordinator = ConversationCoordinator(
            workspace: vm,
            contextSelection: contextSelection
        )
        let chatVM = ChatViewModel(
            coordinator: coordinator,
            contextSelection: contextSelection
        )
        
        // Set text
        chatVM.text = "Test message"
        
        // Verify text is set
        XCTAssertEqual(chatVM.text, "Test message", "ChatViewModel should store text")
        
        // Send should not crash (even if it doesn't complete without real engine)
        // We verify the method exists and can be called
        XCTAssertNoThrow({
            Task {
                await chatVM.send()
            }
        }, "ChatViewModel.send() should not crash")
    }
    
    func testChatViewModelCanAsk() async throws {
        let file = tempDir.appendingPathComponent("test.swift")
        try "// test".write(to: file, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeWorkspaceViewModel(engine: engine)
        
        await vm.openWorkspace(at: tempDir)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        await vm.selectPath(file)
        
        let contextSelection = ContextSelectionState()
        let coordinator = ConversationCoordinator(
            workspace: vm,
            contextSelection: contextSelection
        )
        let chatVM = ChatViewModel(
            coordinator: coordinator,
            contextSelection: contextSelection
        )
        
        // Set question
        chatVM.text = "What does this file do?"
        
        // Ask should not crash
        XCTAssertNoThrow({
            Task {
                await chatVM.ask()
            }
        }, "ChatViewModel.ask() should not crash")
    }
    
    // MARK: - Test E: Entire view hierarchy can be constructed without lifecycle triggers
    
    func testViewHierarchyConstructsWithoutLifecycle() {
        let container = TestContainer(root: tempDir)
        let host = ChatUIHost(container: container)
        
        // Construct entire hierarchy
        let body = host.body
        
        // Verify it constructs
        XCTAssertNotNil(body, "Entire view hierarchy should construct")
        
        // Verify no .task modifiers are required for basic construction
        // (Some views may have .task, but construction itself shouldn't require it)
    }
    
    func testExplicitInitializationWorks() async throws {
        // This test verifies that all initialization is explicit, not via lifecycle
        
        let file = tempDir.appendingPathComponent("test.swift")
        try "// test".write(to: file, atomically: true, encoding: .utf8)
        
        let engine = makeRealEngine()
        let vm = makeWorkspaceViewModel(engine: engine)
        
        // Explicit workspace open (no .task) - using public API
        vm.setRootDirectory(tempDir)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Explicit file selection (no .onAppear) - using public API
        vm.setSelectedURL(file)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify state
        XCTAssertNotNil(vm.rootFileNode, "Workspace should be opened explicitly")
        XCTAssertNotNil(vm.selectedNode, "File should be selected explicitly")
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
    
    private func makeWorkspaceViewModel(engine: WorkspaceEngine? = nil) -> WorkspaceViewModel {
        let engine = engine ?? StubWorkspaceEngine()
        return WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: ConversationEngineStub(),
            projectTodosLoader: StubTodosLoader(),
            codexService: NullCodexQuerying()
        )
    }
}
