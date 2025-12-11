import XCTest
import AppCoreEngine
@testable import UIConnections

@MainActor
final class ContextSnapshotPresentationTests: XCTestCase {
    
    func testDescriptorsSortedByCanonicalPath() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let engine = DeterministicWorkspaceEngine(
            root: root,
            files: [TestWorkspaceFile(relativePath: "b.swift", content: "b"), TestWorkspaceFile(relativePath: "a.swift", content: "a")],
            initialSelection: "a.swift"
        )
        let viewModel = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: FakeCodexService()
        )
        engine.emitUpdate()
        try? await Task.sleep(nanoseconds: 20_000_000)
        
        let attachments = [
            LoadedFile.make(path: root.appendingPathComponent("b.swift").path, content: "b"),
            LoadedFile.make(path: root.appendingPathComponent("a.swift").path, content: "a")
        ]
        let snapshot = viewModel.buildContextSnapshot(from: .from(files: attachments))
        let paths = snapshot.includedFiles.map(\.path)
        XCTAssertEqual(paths, paths.sorted())
    }
    
    func testSnapshotExposesCountsAndHashPrefix() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let engine = DeterministicWorkspaceEngine(
            root: root,
            files: [TestWorkspaceFile(relativePath: "file.swift", content: "1234")],
            initialSelection: "file.swift"
        )
        let viewModel = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: FakeCodexService()
        )
        engine.emitUpdate()
        try? await Task.sleep(nanoseconds: 20_000_000)
        let attachments = [LoadedFile.make(path: root.appendingPathComponent("file.swift").path, content: "1234")]
        let context = ContextBuildResult.from(files: attachments)
        let snapshot = viewModel.buildContextSnapshot(from: context)
        
        XCTAssertEqual(snapshot.includedFiles.count, 1)
        XCTAssertEqual(snapshot.totalBytes, context.totalBytes)
        XCTAssertEqual(snapshot.totalTokens, context.totalTokens)
        XCTAssertEqual(snapshot.snapshotHash?.prefix(8), engine.currentSnapshot.snapshotHash.prefix(8))
    }
    
    func testEmptyWorkspaceProducesNilSnapshot() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let engine = DeterministicWorkspaceEngine(root: root, files: [], initialSelection: nil)
        let viewModel = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: FakeCodexService()
        )
        XCTAssertNil(viewModel.lastContextSnapshot)
    }
    
    func testSegmentationPreserved() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let engine = DeterministicWorkspaceEngine(
            root: root,
            files: [
                TestWorkspaceFile(relativePath: "big.swift", content: "big file"),
                TestWorkspaceFile(relativePath: "second.swift", content: "more")
            ],
            initialSelection: "big.swift"
        )
        let files = [
            LoadedFile.make(path: root.appendingPathComponent("big.swift").path, content: "big file"),
            LoadedFile.make(path: root.appendingPathComponent("second.swift").path, content: "more")
        ]
        let encoded = WorkspaceContextEncoder().encode(files: files)
        let segments = WorkspaceContextSegmenter(maxTokensPerSegment: 1).segment(files: encoded)
        let context = ContextBuildResult.from(files: files, segments: segments)
        let viewModel = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: FakeCodexService()
        )
        engine.emitUpdate()
        try? await Task.sleep(nanoseconds: 20_000_000)
        
        let snapshot = viewModel.buildContextSnapshot(from: context)
        
        XCTAssertEqual(snapshot.segments.count, 2)
        XCTAssertEqual(snapshot.segments.first?.files.first?.path, files.first?.url.path)
    }
}
