import XCTest
@testable import UIConnections
import AppCoreEngine
import AppAdapters

final class AskCodexPipelineTests: XCTestCase {
    func testCodexServiceReceivesOrderedSegmentsAndNoMutationDuringAsk() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ask-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "aaa".write(to: root.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)
        try "bbb".write(to: root.appendingPathComponent("b.swift"), atomically: true, encoding: .utf8)

        let fileSystem = FileSystemAccessAdapter()
        let preferences = PreferencesStoreAdapter<WorkspacePreferences>(strict: false)
        let contextPrefs = ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>(strict: false)
        let watcher = NoopWatcher()
        let workspace = WorkspaceEngineImpl(
            fileSystem: fileSystem,
            preferences: preferences,
            contextPreferences: contextPrefs,
            watcher: watcher
        )
        _ = try await workspace.openWorkspace(rootPath: root.path)
        _ = try await workspace.setContextInclusion(path: root.appendingPathComponent("a.swift").path, included: true)
        _ = try await workspace.setContextInclusion(path: root.appendingPathComponent("b.swift").path, included: true)
        let snapshot = await workspace.snapshot()
        XCTAssertGreaterThan(snapshot.descriptors.filter { $0.type == .file }.count, 1)

        let recorder = RecordingCodexClient()
        let mutation = FakeMutationAuthority()
        let service = CodexService(
            conversationEngine: FakeConversationEngine(),
            workspaceEngine: workspace,
            codexClient: recorder.client(),
            fileLoader: FileContentLoaderAdapter(),
            retryPolicy: RetryPolicyImpl(),
            mutationAuthority: mutation
        )

        let answer = try await service.askAboutWorkspaceNode(scope: .path(root.path), question: "What is here?") { _ in }

        // Assert mutation pipeline not used.
        XCTAssertEqual(mutation.applyCalls, 0, "Mutation pipeline must not run during ask.")

        // Assert segments sent in order with both files.
        let sentMessages = recorder.recordedMessages()
        XCTAssertEqual(sentMessages.count, 2, "Expected system + user message.")
        XCTAssertEqual(sentMessages.count, 2, "Expected system + user message.")
        let user = sentMessages.last?.text ?? ""
        XCTAssertTrue(user.contains("## Context Segment 1"), "User prompt must include segment header.")
        XCTAssertTrue(user.contains("a.swift"), "User prompt must list first file.")
        XCTAssertTrue(user.contains("b.swift"), "User prompt must list second file.")

        // Context order echoed
        let contextFiles = recorder.recordedContextFiles()
        XCTAssertEqual(Set(contextFiles.map { $0.url.lastPathComponent }), Set(["a.swift", "b.swift"]))

        // Streaming echo asserted
        XCTAssertEqual(answer.text, "streamed")
    }

    @MainActor
    func testChatViewModelIntegrationUsesAskPipeline() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("askvm-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileSystem = FileSystemAccessAdapter()
        let preferences = PreferencesStoreAdapter<WorkspacePreferences>(strict: false)
        let contextPrefs = ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>(strict: false)
        let watcher = NoopWatcher()
        let workspaceEngine = WorkspaceEngineImpl(
            fileSystem: fileSystem,
            preferences: preferences,
            contextPreferences: contextPrefs,
            watcher: watcher
        )
        let fileURL = root.appendingPathComponent("file.swift")
        XCTAssertNoThrow(try "content".write(to: fileURL, atomically: true, encoding: .utf8))
        _ = try await workspaceEngine.openWorkspace(rootPath: root.path)
        let recorder = RecordingCodexClient()
        let mutation = FakeMutationAuthority()
        let codex = CodexService(
            conversationEngine: FakeConversationEngine(),
            workspaceEngine: workspaceEngine,
            codexClient: recorder.client(),
            fileLoader: FileContentLoaderAdapter(),
            retryPolicy: RetryPolicyImpl(),
            mutationAuthority: mutation
        )
        let selection = ContextSelectionState()
        selection.setScopeChoice(.selection)
        let workspaceVM = WorkspaceViewModel(
            workspaceEngine: workspaceEngine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: codex,
            contextSelection: selection
        )
        workspaceVM.setSelectedURL(fileURL)
        try await Task.sleep(nanoseconds: 50_000_000)
        let coordinator = ConversationCoordinator(workspace: workspaceVM, contextSelection: selection)
        let vm = ChatViewModel(coordinator: coordinator, contextSelection: selection)

        vm.text = "Question?"
        let convo = Conversation()
        let exp = expectation(description: "ask completes")
        vm.askCodex(conversation: convo) { updated in
            XCTAssertEqual(updated.messages.last?.role, .assistant)
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 5.0)

        // Ensure pipeline ran without mutations
        XCTAssertEqual(mutation.applyCalls, 0)
        let messages = recorder.recordedMessages()
        XCTAssertEqual(messages.count, 2)
        let userPrompt = messages.last?.text ?? ""
        XCTAssertTrue(userPrompt.contains("## Context Segment 1"), "Prompt should include context segment header")
        XCTAssertFalse(recorder.recordedContextFiles().isEmpty, "Context files should be sent")
    }
}

// MARK: - Recording codex client
private final class RecordingCodexClient {
    private let queue = DispatchQueue(label: "recording-codex-client")
    private var messages: [Message] = []
    private var contextFiles: [LoadedFile] = []

    func client() -> AnyCodexClient {
        AnyCodexClient { messages, contextFiles in
            self.record(messages: messages, contextFiles: contextFiles)
            return AsyncThrowingStream { continuation in
                continuation.yield(.token(""))
                continuation.yield(.output(ModelResponse(content: "streamed")))
                continuation.yield(.done)
                continuation.finish()
            }
        }
    }

    private func record(messages: [Message], contextFiles: [LoadedFile]) {
        queue.sync {
            self.messages = messages
            self.contextFiles = contextFiles
        }
    }

    func recordedMessages() -> [Message] {
        queue.sync { messages }
    }

    func recordedContextFiles() -> [LoadedFile] {
        queue.sync { contextFiles }
    }
}

private final class NoopWatcher: FileSystemWatching {
    func watch(rootPath: String) -> AsyncStream<Void> {
        AsyncStream { _ in }
    }
}
