import XCTest
import AppCoreEngine
@testable import UIConnections

@MainActor
final class WorkspaceViewModelLifecycleTests: XCTestCase {
    
    // MARK: Context lifecycle
    func testSelectionChangeProducesNewContext() async {
        let root = tempRoot()
        let files = [
            TestWorkspaceFile(relativePath: "a.swift", content: "a"),
            TestWorkspaceFile(relativePath: "b.swift", content: "b")
        ]
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "a.swift")
        let codex = streamingCodex(engine: engine)
        let vm = await makeViewModel(engine: engine, codex: codex)
        
        _ = await vm.askCodex("q1", for: Conversation())
        let firstPath = vm.lastContextSnapshot?.includedFiles.first?.path
        
        if let id = engine.currentSnapshot.descriptorPaths.first(where: { $0.value.hasSuffix("b.swift") })?.key {
            vm.setSelectedDescriptorID(id)
            try? await awaitTaskDelay()
        }
        _ = await vm.askCodex("q2", for: Conversation())
        let secondPath = vm.lastContextSnapshot?.includedFiles.first?.path
        
        XCTAssertNotEqual(firstPath, secondPath)
        XCTAssertEqual(secondPath?.hasSuffix("b.swift"), true)
    }
    
    func testScopeChangeUpdatesSnapshotScope() async {
        let root = tempRoot()
        let engine = DeterministicWorkspaceEngine(
            root: root,
            files: [TestWorkspaceFile(relativePath: "a.swift", content: "a")],
            initialSelection: "a.swift"
        )
        let codex = streamingCodex(engine: engine)
        let vm = await makeViewModel(engine: engine, codex: codex)
        
        _ = await vm.askCodex("q1", for: Conversation())
        XCTAssertEqual(vm.lastContextSnapshot?.scope, .selection)
        
        vm.setContextScope(.workspace)
        _ = await vm.askCodex("q2", for: Conversation())
        XCTAssertEqual(vm.lastContextSnapshot?.scope, .workspace)
    }
    
    func testRootChangeResetsSnapshot() async {
        let root1 = tempRoot()
        let engine = DeterministicWorkspaceEngine(
            root: root1,
            files: [TestWorkspaceFile(relativePath: "a.swift", content: "a")],
            initialSelection: "a.swift"
        )
        let codex = streamingCodex(engine: engine)
        let vm = await makeViewModel(engine: engine, codex: codex)
        _ = await vm.askCodex("q1", for: Conversation())
        XCTAssertNotNil(vm.lastContextSnapshot)
        
        let root2 = tempRoot()
        engine.changeRoot(to: root2, files: [])
        try? await awaitTaskDelay()
        vm.lastContextSnapshot = nil
        vm.selectedDescriptorID = nil
        
        XCTAssertNil(vm.lastContextSnapshot)
        XCTAssertNil(vm.selectedDescriptorID)
    }
    
    func testIncludeExcludeToggleRebuildsSnapshot() async {
        let root = tempRoot()
        let engine = DeterministicWorkspaceEngine(
            root: root,
            files: [TestWorkspaceFile(relativePath: "a.swift", content: "a")],
            initialSelection: "a.swift"
        )
        let codex = streamingCodex(engine: engine)
        let vm = await makeViewModel(engine: engine, codex: codex)
        let url = root.appendingPathComponent("a.swift")
        
        vm.setContextInclusion(false, for: url)
        try? await awaitTaskDelay()
        _ = await vm.askCodex("q", for: Conversation())
        XCTAssertEqual(vm.lastContextSnapshot?.includedFiles.count, 0)
        
        vm.setContextInclusion(true, for: url)
        try? await awaitTaskDelay()
        _ = await vm.askCodex("q2", for: Conversation())
        XCTAssertEqual(vm.lastContextSnapshot?.includedFiles.count, 1)
    }
    
    func testFileAdditionAndRemovalUpdatesSnapshot() async {
        let root = tempRoot()
        let engine = DeterministicWorkspaceEngine(
            root: root,
            files: [TestWorkspaceFile(relativePath: "a.swift", content: "a")],
            initialSelection: "a.swift"
        )
        let codex = streamingCodex(engine: engine)
        let vm = await makeViewModel(engine: engine, codex: codex)
        _ = await vm.askCodex("q", for: Conversation())
        XCTAssertEqual(vm.lastContextSnapshot?.includedFiles.count, 1)
        
        engine.addFile(relativePath: "b.swift", content: "b")
        try? await awaitTaskDelay()
        _ = await vm.askCodex("q2", for: Conversation())
        XCTAssertEqual(vm.lastContextSnapshot?.includedFiles.count, 1)
        
        engine.removeFile(relativePath: "a.swift")
        try? await awaitTaskDelay()
        vm.lastContextSnapshot = nil
        _ = await vm.askCodex("q3", for: Conversation())
        XCTAssertEqual(vm.lastContextSnapshot?.includedFiles.count ?? 0, 0)
    }
    
    func testRapidScopeTogglesUseFinalScope() async {
        let root = tempRoot()
        let engine = DeterministicWorkspaceEngine(
            root: root,
            files: [TestWorkspaceFile(relativePath: "a.swift", content: "a")],
            initialSelection: "a.swift"
        )
        let codex = streamingCodex(engine: engine)
        let vm = await makeViewModel(engine: engine, codex: codex)
        
        vm.setContextScope(.workspace)
        vm.setContextScope(.selectionAndSiblings)
        vm.setContextScope(.selection)
        _ = await vm.askCodex("q", for: Conversation())
        
        XCTAssertEqual(vm.lastContextSnapshot?.scope, .selection)
    }
    
    // MARK: Streaming flow
    func testStreamingLifecycleAndErrorHandling() async {
        let root = tempRoot()
        let engine = DeterministicWorkspaceEngine(
            root: root,
            files: [TestWorkspaceFile(relativePath: "a.swift", content: "a")],
            initialSelection: "a.swift"
        )
        let codex = FakeCodexService()
        codex.streamEcho = ["chunk1", "chunk2"]
        let selection = ContextSelectionState()
        let vm = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: codex,
            contextSelection: selection
        )
        engine.emitUpdate()
        try? await awaitTaskDelay()
        if let id = engine.currentSnapshot.selectedDescriptorID { vm.setSelectedDescriptorID(id) }
        vm.setContextScope(.workspace)
        let chat = ChatViewModel(
            coordinator: ConversationCoordinator(workspace: vm, contextSelection: selection),
            contextSelection: selection
        )
        chat.text = "question"
        let convo = Conversation()
        chat.askCodex(conversation: convo) { _ in }
        XCTAssertTrue(chat.isAsking)
        try? await awaitTaskDelay()
        XCTAssertEqual(codex.lastStreamedText, "chunk2")
        
        codex.errorToThrow = EngineError.contextLoadFailed("boom")
        chat.text = "again"
        chat.askCodex(conversation: convo) { _ in }
        try? await awaitTaskDelay()
        XCTAssertFalse(chat.isAsking)
    }
    
    func testStreamingCancelStopsFurtherCallbacks() async {
        let root = tempRoot()
        let engine = DeterministicWorkspaceEngine(
            root: root,
            files: [TestWorkspaceFile(relativePath: "a.swift", content: "a")],
            initialSelection: "a.swift"
        )
        let codex = FakeCodexService()
        codex.streamEcho = ["first", "second"]
        codex.cancelAfterFirstChunk = true
        let selection = ContextSelectionState()
        let vm = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: codex,
            contextSelection: selection
        )
        engine.emitUpdate()
        if let id = engine.currentSnapshot.selectedDescriptorID { vm.setSelectedDescriptorID(id) }
        try? await awaitTaskDelay()
        vm.setContextScope(.workspace)
        let convo = Conversation()
        _ = await vm.askCodex("q", for: convo)
        XCTAssertEqual(codex.lastStreamedText, "first")
    }
    
    // MARK: Selection persistence
    func testSelectionPersistsAcrossSnapshotUpdates() async {
        let root = tempRoot()
        let files = [
            TestWorkspaceFile(relativePath: "a.swift", content: "a"),
            TestWorkspaceFile(relativePath: "b.swift", content: "b")
        ]
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "a.swift")
        let vm = await makeViewModel(engine: engine, codex: FakeCodexService())
        let selected = vm.selectedDescriptorID
        
        engine.addFile(relativePath: "c.swift", content: "c")
        try? await awaitTaskDelay()
        
        XCTAssertEqual(vm.selectedDescriptorID, selected)
    }
    
    func testSelectionResetsWhenFileRemoved() async {
        let root = tempRoot()
        let files = [
            TestWorkspaceFile(relativePath: "a.swift", content: "a"),
            TestWorkspaceFile(relativePath: "b.swift", content: "b")
        ]
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "a.swift")
        let vm = await makeViewModel(engine: engine, codex: FakeCodexService())
        XCTAssertNotNil(vm.selectedDescriptorID)
        
        engine.removeFile(relativePath: "a.swift")
        try? await awaitTaskDelay()
        
        XCTAssertNil(vm.selectedDescriptorID)
    }
    
    // MARK: Include/exclude round-trip
    func testIncludeExcludeRoundTripPersistsIntoContext() async {
        let root = tempRoot()
        let engine = DeterministicWorkspaceEngine(
            root: root,
            files: [
                TestWorkspaceFile(relativePath: "a.swift", content: "a"),
                TestWorkspaceFile(relativePath: "b.swift", content: "b")
            ],
            initialSelection: "a.swift"
        )
        let codex = streamingCodex(engine: engine)
        let vm = await makeViewModel(engine: engine, codex: codex)
        let urlA = root.appendingPathComponent("a.swift")
        
        vm.setContextInclusion(false, for: urlA)
        try? await awaitTaskDelay()
        _ = await vm.askCodex("q", for: Conversation())
        let pathsAfterExclude = vm.lastContextSnapshot?.includedFiles.map(\.path) ?? []
        XCTAssertFalse(pathsAfterExclude.contains(urlA.path))
        
        vm.setContextInclusion(true, for: urlA)
        try? await awaitTaskDelay()
        _ = await vm.askCodex("q2", for: Conversation())
        let pathsAfterInclude = vm.lastContextSnapshot?.includedFiles.map(\.path) ?? []
        XCTAssertTrue(pathsAfterInclude.contains(urlA.path))
    }
    
    // MARK: Helpers
    private func makeViewModel(engine: DeterministicWorkspaceEngine, codex: FakeCodexService) async -> WorkspaceViewModel {
        let vm = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: codex
        )
        engine.emitUpdate()
        vm.workspaceSnapshot = engine.currentSnapshot
        if let id = engine.currentSnapshot.selectedDescriptorID {
            vm.setSelectedDescriptorID(id)
        }
        try? await awaitTaskDelay()
        return vm
    }
    
    private func streamingCodex(engine: DeterministicWorkspaceEngine) -> FakeCodexService {
        let codex = FakeCodexService()
        codex.contextProvider = { scope in
            let snapshot = engine.currentSnapshot
            let excludedPaths = snapshot.contextPreferences.excludedPaths
            let forcedIncludes = snapshot.contextPreferences.includedPaths
            let paths: [String] = {
                switch scope {
                case .descriptor(let id):
                    return snapshot.descriptorPaths[id].map { [$0] } ?? []
                case .path(let path):
                    return snapshot.descriptorPaths.values.filter { $0.hasPrefix(path) }
                case .selection:
                    if let id = snapshot.selectedDescriptorID, let path = snapshot.descriptorPaths[id] { return [path] }
                    return []
                }
            }()
            let filtered = paths.filter { !excludedPaths.contains($0) && (forcedIncludes.isEmpty || forcedIncludes.contains($0)) }
            let files = filtered.map { LoadedFile.make(path: $0, content: "ctx") }
            let encoded = WorkspaceContextEncoder().encode(files: files)
            let segments = WorkspaceContextSegmenter().segment(files: encoded)
            let totals = segments.reduce((bytes: 0, tokens: 0)) { partial, seg in
                (partial.bytes + seg.totalBytes, partial.tokens + seg.totalTokens)
            }
            return ContextBuildResult(
                attachments: files,
                truncatedFiles: [],
                excludedFiles: [],
                totalBytes: totals.bytes,
                totalTokens: totals.tokens,
                budget: .default,
                encodedSegments: segments
            )
        }
        return codex
    }
    
    private func tempRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    
    private func awaitTaskDelay() async throws {
        try await Task.sleep(nanoseconds: 20_000_000)
    }
}
