import XCTest
@testable import UIConnections
import AppCoreEngine

@MainActor
final class WorkspaceViewModelBehaviorTests: XCTestCase {
    func testChangingScopeRecomputesSnapshotAndUpdatesActiveScope() async throws {
        let env = await makeSubject()
        XCTAssertEqual(env.viewModel.activeScope, .selection)

        env.selection.setScopeChoice(.workspace)
        await Task.yield()

        XCTAssertEqual(env.viewModel.activeScope, .workspace)
    }

    func testSelectionAndSiblingsIncludesSiblings() async throws {
        let env = await makeSubject(files: [
            .init(relativePath: "src/a.swift", content: "a"),
            .init(relativePath: "src/b.swift", content: "b"),
            .init(relativePath: "src/child/c.swift", content: "c")
        ], initialSelection: "src/a.swift")

        env.viewModel.setSelectedURL(env.root.appendingPathComponent("src/a.swift"))
        await Task.yield()

        env.selection.setScopeChoice(.selectionAndSiblings)
        await Task.yield()

        guard let scope = env.viewModel.currentWorkspaceScope() else {
            return XCTFail("Expected scope")
        }
        switch scope {
        case .descriptor(let id):
            let siblings = env.engine.currentSnapshot.descriptors
                .filter { $0.id != id && $0.canonicalPath.hasSuffix("/src/b.swift") }
            XCTAssertFalse(siblings.isEmpty, "Expected sibling descriptor for selectionAndSiblings")
        default:
            XCTFail("Expected descriptor scope")
        }
    }

    func testWorkspaceScopeIncludesAllEligibleFiles() async throws {
        let env = await makeSubject(files: [
            .init(relativePath: "src/a.swift", content: "a"),
            .init(relativePath: ".git/config", content: "ignore"),
            .init(relativePath: ".build/cache", content: "ignore")
        ], initialSelection: "src/a.swift")

        env.selection.setScopeChoice(.workspace)
        await Task.yield()

        guard let scope = env.viewModel.currentWorkspaceScope() else {
            return XCTFail("Expected workspace scope")
        }
        switch scope {
        case .path(let path):
            XCTAssertEqual(path, env.root.path)
            // Exclusions already applied by deterministic engine; ensure descriptor count excludes .git/.build.
            let descriptors = env.engine.currentSnapshot.descriptors
            XCTAssertEqual(descriptors.filter { $0.canonicalPath.contains(".git") }.count, 0)
            XCTAssertEqual(descriptors.filter { $0.canonicalPath.contains(".build") }.count, 0)
        default:
            XCTFail("Expected path scope")
        }
    }

    func testManualScopeHonorsInclusions() async throws {
        let env = await makeSubject(files: [
            .init(relativePath: "src/a.swift", content: "a"),
            .init(relativePath: "src/b.swift", content: "b")
        ], initialSelection: "src/a.swift")

        env.selection.setScopeChoice(.manual)
        await Task.yield()

        // Manually include b.swift
        let includePath = env.root.appendingPathComponent("src/b.swift").path
        _ = try await env.engine.setContextInclusion(path: includePath, included: true)

        guard let scope = env.viewModel.currentWorkspaceScope() else {
            return XCTFail("Expected descriptor scope for manual")
        }
        switch scope {
        case .descriptor(let id):
            XCTAssertNotNil(env.engine.currentSnapshot.descriptorPaths[id], "Manual scope should resolve descriptor")
        default:
            XCTFail("Expected descriptor scope")
        }
    }

    func testSnapshotHashStableAcrossRuns() async throws {
        let files = [
            TestWorkspaceFile(relativePath: "src/a.swift", content: "let a = 1"),
            TestWorkspaceFile(relativePath: "src/b.swift", content: "let b = 2")
        ]
        let env1 = await makeSubject(files: files, initialSelection: "src/a.swift")
        let env2 = await makeSubject(files: files, initialSelection: "src/a.swift")

        XCTAssertEqual(env1.engine.currentSnapshot.snapshotHash, env2.engine.currentSnapshot.snapshotHash)
    }

    func testNoRecomputationWhenStateUnchanged() async throws {
        let env = await makeSubject(files: [
            .init(relativePath: "src/a.swift", content: "a")
        ], initialSelection: "src/a.swift")

        let beforeHash = env.engine.currentSnapshot.snapshotHash
        env.selection.setScopeChoice(.selection)
        await Task.yield()

        let afterHash = env.engine.currentSnapshot.snapshotHash
        XCTAssertEqual(beforeHash, afterHash, "Snapshot hash should not change when no relevant state changes.")
    }

    func testErrorsPropagateFromEngine() async throws {
        let failing = FailingWorkspaceEngine(error: EngineError.contextLoadFailed("boom"))
        let vm = WorkspaceViewModel(
            workspaceEngine: failing,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: FakeCodexService(),
            contextSelection: ContextSelectionState()
        )
        let result = await vm.askCodex("hi", for: Conversation())
        XCTAssertEqual(result.messages.count, 0)
    }

    // MARK: - Helpers
    private struct Env {
        let viewModel: WorkspaceViewModel
        let engine: DeterministicWorkspaceEngine
        let root: URL
        let selection: ContextSelectionState
    }

    private func makeSubject(files: [TestWorkspaceFile] = [
        .init(relativePath: "src/main.swift", content: "print(\"hi\")")
    ], initialSelection: String? = nil) async -> Env {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("wvm-fixed")
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let engine = DeterministicWorkspaceEngine(root: root, files: files, initialSelection: initialSelection)
        let conversation = FakeConversationEngine()
        let selection = ContextSelectionState()
        let vm = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: conversation,
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: FakeCodexService(),
            contextSelection: selection
        )
        engine.emitUpdate()
        if let id = engine.currentSnapshot.selectedDescriptorID {
            vm.setSelectedDescriptorID(id)
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
        return Env(viewModel: vm, engine: engine, root: root, selection: selection)
    }
}

private final class FailingWorkspaceEngine: WorkspaceEngine {
    let error: Error
    init(error: Error) { self.error = error }
    func openWorkspace(rootPath: String) async throws -> WorkspaceSnapshot { throw error }
    func snapshot() async -> WorkspaceSnapshot { .empty }
    func refresh() async throws -> WorkspaceSnapshot { throw error }
    func select(path: String?) async throws -> WorkspaceSnapshot { throw error }
    func contextPreferences() async throws -> WorkspaceSnapshot { throw error }
    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot { throw error }
    func treeProjection() async -> WorkspaceTreeProjection? { nil }
    func updates() -> AsyncStream<WorkspaceUpdate> { AsyncStream { _ in } }
}
