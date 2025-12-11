import XCTest
import AppCoreEngine
@testable import UIConnections

@MainActor
final class WorkspaceViewModelMutationSafetyTests: XCTestCase {
    
    func testAskCodexNeverInvokesMutationAuthority() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = [TestWorkspaceFile(relativePath: "file.swift", content: "body")]
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "file.swift")
        let mutationAuthority = FakeMutationAuthority()
        let codex = FakeCodexService()
        codex.contextProvider = { _ in
            ContextBuildResult.from(files: [LoadedFile.make(path: root.appendingPathComponent("file.swift").path, content: "body")])
        }
        let viewModel = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: codex
        )
        engine.emitUpdate()
        try? await Task.sleep(nanoseconds: 20_000_000)
        if let id = engine.currentSnapshot.selectedDescriptorID {
            viewModel.setSelectedDescriptorID(id)
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        
        _ = await viewModel.askCodex("question", for: Conversation())
        
        XCTAssertEqual(mutationAuthority.applyCalls, 0)
        XCTAssertEqual(codex.mutationAttempts, 0)
    }
    
    func testAskCodexPipelineIsReadOnly() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = [TestWorkspaceFile(relativePath: "file.swift", content: "body")]
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "file.swift")
        let codex = FakeCodexService()
        codex.streamEcho = ["partial"]
        codex.contextProvider = { _ in
            ContextBuildResult.from(files: [LoadedFile.make(path: root.appendingPathComponent("file.swift").path, content: "body")])
        }
        let viewModel = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: codex
        )
        engine.emitUpdate()
        try? await Task.sleep(nanoseconds: 20_000_000)
        if let id = engine.currentSnapshot.selectedDescriptorID {
            viewModel.setSelectedDescriptorID(id)
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        
        _ = await viewModel.askCodex("question", for: Conversation())
        
        XCTAssertEqual(codex.calls.count, 1)
        XCTAssertEqual(codex.mutationAttempts, 0)
    }
}
