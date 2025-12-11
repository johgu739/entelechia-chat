import XCTest
import AppCoreEngine
@testable import UIConnections

@MainActor
final class WorkspaceViewModelContextTests: XCTestCase {
    
    func testSelectionScopeUsesOnlySelectedFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = [
            TestWorkspaceFile(relativePath: "src/selected.swift", content: "first"),
            TestWorkspaceFile(relativePath: "src/other.swift", content: "second")
        ]
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "src/selected.swift")
        let codex = scopeAwareCodex(using: engine, mode: .selection)
        let viewModel = await makeViewModel(engine: engine, codex: codex)
        
        _ = await viewModel.askCodex("question", for: Conversation())
        
        XCTAssertEqual(codex.calls.last?.scope, .descriptor(engine.currentSnapshot.selectedDescriptorID!))
        XCTAssertEqual(viewModel.lastContextSnapshot?.includedFiles.count, 1)
        XCTAssertEqual(viewModel.lastContextSnapshot?.includedFiles.first?.path, root.appendingPathComponent("src/selected.swift").path)
    }
    
    func testWorkspaceScopeIncludesAllNonExcludedFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = [
            TestWorkspaceFile(relativePath: "src/a.swift", content: "a"),
            TestWorkspaceFile(relativePath: "src/nested/b.swift", content: "b"),
            TestWorkspaceFile(relativePath: ".git/config", content: "ignored")
        ]
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "src/a.swift")
        let codex = scopeAwareCodex(using: engine, mode: .workspace)
        let viewModel = await makeViewModel(engine: engine, codex: codex)
        viewModel.setContextScope(.workspace)
        
        _ = await viewModel.askCodex("question", for: Conversation())
        
        let includedPaths = viewModel.lastContextSnapshot?.includedFiles.map(\.path) ?? []
        XCTAssertTrue(includedPaths.contains(root.appendingPathComponent("src/a.swift").path))
        XCTAssertTrue(includedPaths.contains(root.appendingPathComponent("src/nested/b.swift").path))
        XCTAssertFalse(includedPaths.contains(root.appendingPathComponent(".git/config").path))
    }
    
    func testSelectionAndSiblingsIncludesPeers() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = [
            TestWorkspaceFile(relativePath: "src/folder/selected.swift", content: "s"),
            TestWorkspaceFile(relativePath: "src/folder/sibling.swift", content: "sib"),
            TestWorkspaceFile(relativePath: "src/other/file.swift", content: "nope")
        ]
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "src/folder/selected.swift")
        let codex = scopeAwareCodex(using: engine, mode: .selectionAndSiblings)
        let viewModel = await makeViewModel(engine: engine, codex: codex)
        viewModel.setContextScope(.selectionAndSiblings)
        
        _ = await viewModel.askCodex("question", for: Conversation())
        
        let includedPaths = viewModel.lastContextSnapshot?.includedFiles.map(\.path) ?? []
        XCTAssertTrue(includedPaths.contains(root.appendingPathComponent("src/folder/selected.swift").path))
        XCTAssertTrue(includedPaths.contains(root.appendingPathComponent("src/folder/sibling.swift").path))
        XCTAssertFalse(includedPaths.contains(root.appendingPathComponent("src/other/file.swift").path))
    }
    
    func testManualScopeRespectsManualInclusions() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = [
            TestWorkspaceFile(relativePath: "src/manual.swift", content: "m"),
            TestWorkspaceFile(relativePath: "src/skip.swift", content: "x")
        ]
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "src/manual.swift")
        let codex = scopeAwareCodex(using: engine, mode: .manual)
        let viewModel = await makeViewModel(engine: engine, codex: codex)
        viewModel.setContextScope(.manual)
        
        let includeURL = root.appendingPathComponent("src/manual.swift")
        viewModel.setContextInclusion(true, for: includeURL)
        try? await Task.sleep(nanoseconds: 20_000_000)
        _ = await viewModel.askCodex("question", for: Conversation())
        
        let includedPaths = viewModel.lastContextSnapshot?.includedFiles.map(\.path) ?? []
        XCTAssertEqual(includedPaths, [includeURL.path])
    }
    
    func testSnapshotHashDeterministicAcrossBuilds() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = [TestWorkspaceFile(relativePath: "file.swift", content: "body")]
        let engineA = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "file.swift")
        let engineB = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "file.swift")
        XCTAssertEqual(engineA.currentSnapshot.snapshotHash, engineB.currentSnapshot.snapshotHash)
    }
    
    func testInvalidSelectionDisablesAsk() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = [TestWorkspaceFile(relativePath: "file.swift", content: "body")]
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: nil)
        let codex = scopeAwareCodex(using: engine, mode: .selection)
        let viewModel = await makeViewModel(engine: engine, codex: codex)
        viewModel.setContextScope(.selection)
        
        let conversation = await viewModel.askCodex("question", for: Conversation())
        XCTAssertEqual(conversation.messages.count, 0)
        XCTAssertNil(viewModel.lastContextSnapshot)
        XCTAssertTrue(codex.calls.isEmpty)
    }
    
    func testSegmentationMatchesUnderlyingResult() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = [TestWorkspaceFile(relativePath: "file.swift", content: "content")]
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: "file.swift")
        let contextFiles = [LoadedFile.make(path: root.appendingPathComponent("file.swift").path, content: "content")]
        let encoded = WorkspaceContextEncoder().encode(files: contextFiles)
        let segments = WorkspaceContextSegmenter().segment(files: encoded)
        let codex = FakeCodexService(contextResult: .from(files: contextFiles, segments: segments))
        let viewModel = await makeViewModel(engine: engine, codex: codex)
        
        _ = await viewModel.askCodex("question", for: Conversation())
        
        XCTAssertEqual(viewModel.lastContextSnapshot?.segments.count, 1)
        XCTAssertEqual(viewModel.lastContextSnapshot?.segments.first?.files.map { $0.path }, contextFiles.map { $0.url.path })
    }
    
    // MARK: - Helpers
    private func makeViewModel(engine: DeterministicWorkspaceEngine, codex: FakeCodexService) async -> WorkspaceViewModel {
        let vm = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: codex
        )
        engine.emitUpdate()
        try? await Task.sleep(nanoseconds: 20_000_000)
        return vm
    }
    
    private func scopeAwareCodex(using engine: DeterministicWorkspaceEngine, mode: ContextScopeChoice) -> FakeCodexService {
        let codex = FakeCodexService()
        codex.contextProvider = { scope in
            let snapshot = engine.currentSnapshot
            let paths = self.pathsFor(scope: scope, snapshot: snapshot, mode: mode)
            let files = paths.map { LoadedFile.make(path: $0, content: "ctx") }
            let encoded = WorkspaceContextEncoder().encode(files: files)
            let segments = WorkspaceContextSegmenter().segment(files: encoded)
            let totals = segments.reduce((tokens: 0, bytes: 0)) { partial, segment in
                (partial.tokens + segment.totalTokens, partial.bytes + segment.totalBytes)
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
    
    private func pathsFor(scope: WorkspaceScope, snapshot: WorkspaceSnapshot, mode: ContextScopeChoice) -> [String] {
        if mode == .manual {
            return Array(snapshot.contextPreferences.includedPaths).sorted()
        }
        switch scope {
        case .descriptor(let id):
            guard let selectedPath = snapshot.descriptorPaths[id] else { return [] }
            let parent = URL(fileURLWithPath: selectedPath).deletingLastPathComponent().path
            if mode == .selection {
                return [selectedPath]
            }
            let siblings = snapshot.descriptorPaths.values.filter {
                URL(fileURLWithPath: $0).deletingLastPathComponent().path == parent
            }
            return Array(Set([selectedPath] + siblings)).sorted()
        case .path(let path):
            let fileIDs = Set(snapshot.descriptors.filter { $0.type == .file }.map(\.id))
            return snapshot.descriptorPaths
                .filter { fileIDs.contains($0.key) && $0.value.hasPrefix(path) }
                .map(\.value)
                .sorted()
        case .selection:
            if let id = snapshot.selectedDescriptorID, let path = snapshot.descriptorPaths[id] {
                return mode == .selection ? [path] : [path]
            }
            return []
        }
    }
}
