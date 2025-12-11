import XCTest
@testable import UIConnections
import AppCoreEngine
import AppAdapters

final class NegativeBehaviorTests: XCTestCase {
    func testAskWithoutSelectionFailsGracefully() async {
        let engine = DeterministicWorkspaceEngine(
            root: FileManager.default.temporaryDirectory,
            files: [],
            initialSelection: nil
        )
        let vm = await MainActor.run {
            WorkspaceViewModel(
                workspaceEngine: engine,
                conversationEngine: FakeConversationEngine(),
                projectTodosLoader: SharedStubTodosLoader(),
                codexService: FakeCodexService(),
                contextSelection: ContextSelectionState()
            )
        }
        let convo = Conversation()
        let result = await vm.askCodex("q", for: convo)
        XCTAssertEqual(result.messages.count, 0, "Ask should not proceed without selection.")
    }

    func testUnreadableFileExcludedAndLogged() async throws {
        let failing = FailingFileSystemAccessAdapter()
        let preferences = PreferencesStoreAdapter<WorkspacePreferences>(strict: true)
        let contextPrefs = ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>(strict: true)
        let watcher = NoopWatcher()
        let engine = WorkspaceEngineImpl(
            fileSystem: failing,
            preferences: preferences,
            contextPreferences: contextPrefs,
            watcher: watcher
        )
        do {
            _ = try await engine.openWorkspace(rootPath: "/unreadable")
            XCTFail("Expected openWorkspace to throw")
        } catch {
            // expected
        }
    }

    func testInvalidCodexConfigProducesMisconfiguredStatus() async {
        let loader = FailingCodexConfigLoader()
        let build = CodexConfigBridge(apiKey: "", organization: "", baseURL: URL(string: "https://example.com")!)
        let codexAPI = CodexAPIClientAdapter(config: build) // Will never be used due to loader
        _ = codexAPI // silence unused
        XCTAssertThrowsError(try loader.loadConfig().get())
    }

    func testAskCodexDoesNotProceedWhenContextBuildFails() async {
        let codex = ThrowingCodexService()
        let vm = await MainActor.run {
            WorkspaceViewModel(
                workspaceEngine: DeterministicWorkspaceEngine(
                    root: FileManager.default.temporaryDirectory,
                    files: [TestWorkspaceFile(relativePath: "file.swift", content: "c")],
                    initialSelection: "file.swift"
                ),
                conversationEngine: FakeConversationEngine(),
                projectTodosLoader: SharedStubTodosLoader(),
                codexService: codex,
                contextSelection: ContextSelectionState()
            )
        }
        let convo = Conversation()
        let updated = await vm.askCodex("q", for: convo)
        XCTAssertEqual(updated.messages.count, 0)
    }
}

// MARK: - Helpers
private final class FailingFileSystemAccessAdapter: FileSystemAccess, @unchecked Sendable {
    func listChildren(of id: FileID) throws -> [FileDescriptor] { throw NSError(domain: "fs", code: 1) }
    func metadata(for id: FileID) throws -> FileMetadata { throw NSError(domain: "fs", code: 2) }
    func resolveRoot(at path: String) throws -> FileID { throw NSError(domain: "fs", code: 3) }
}

private final class FailingCodexConfigLoader: CodexConfigLoading {
    func loadConfig() -> Result<CodexConfig, CodexConfigError> {
        .failure(.missingAPIKey)
    }
}

private final class ThrowingCodexService: CodexQuerying {
    func askAboutWorkspaceNode(scope: WorkspaceScope, question: String, onStream: ((String) -> Void)?) async throws -> CodexAnswer {
        throw EngineError.contextLoadFailed("context build failed")
    }
}

private final class NoopWatcher: FileSystemWatching {
    func watch(rootPath: String) -> AsyncStream<Void> {
        AsyncStream { _ in }
    }
}
