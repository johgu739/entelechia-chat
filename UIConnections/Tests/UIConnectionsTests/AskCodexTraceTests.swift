import XCTest
@testable import UIConnections
import AppAdapters
import AppCoreEngine

/// Trace-only tests to capture the full AskCodex causal chain without touching production code.
@MainActor
final class AskCodexTraceTests: XCTestCase {
    /// Full pipeline trace: ChatViewModel -> ConversationCoordinator -> WorkspaceViewModel -> CodexService -> AnyCodexClient.
    func test_trace_full_ask_codex_pipeline() async throws {
        let log = TraceLog()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("trace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileA = root.appendingPathComponent("a.swift")
        let fileB = root.appendingPathComponent("b.swift")
        try "aaa".write(to: fileA, atomically: true, encoding: .utf8)
        try "bbb".write(to: fileB, atomically: true, encoding: .utf8)

        // Workspace engine (real)
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
        _ = try await workspaceEngine.openWorkspace(rootPath: root.path)

        // Recorder client
        let recorder = TraceRecordingCodexClient()
        let codex = CodexService(
            conversationEngine: FakeConversationEngine(),
            workspaceEngine: workspaceEngine,
            codexClient: recorder.client(),
            fileLoader: FileContentLoaderAdapter(),
            retryPolicy: RetryPolicyImpl(),
            mutationAuthority: FakeMutationAuthority()
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
        workspaceVM.setSelectedURL(fileA)
        try await Task.sleep(nanoseconds: 50_000_000) // allow async selection

        let proxy = TracingWorkspaceProxy(inner: workspaceVM, log: log)
        let coordinator = ConversationCoordinator(workspace: proxy, contextSelection: selection)
        let chatVM = ChatViewModel(coordinator: coordinator, contextSelection: selection)

        chatVM.text = "What is here?"
        log.add("ChatViewModel.askCodex: isAsking before = \(chatVM.isAsking)")
        let exp = expectation(description: "ask completes")
        chatVM.askCodex(conversation: Conversation()) { updated in
            log.add("ChatViewModel.askCodex: onResult messages=\(updated.messages.count) text=\(self.lastAssistantText(updated))")
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 5.0)
        log.add("ChatViewModel.askCodex: isAsking after = \(chatVM.isAsking) text='\(chatVM.text)'")

        // Snapshot/log capture
        log.add("Recorder messages count=\(recorder.recordedMessages().count)")
        if let user = recorder.recordedMessages().last?.text {
            log.add("User prompt:\n\(user)")
        } else {
            log.add("User prompt missing")
        }
        log.add("Recorder context files=\(recorder.recordedContextFiles().map { $0.url.lastPathComponent })")

        // Emit log for inspection
        log.flush()

        // Keep failing assert to highlight missing context/segments if present.
        XCTAssertTrue(recorder.recordedMessages().last?.text.contains("## Context Segment 1") == true, "Prompt missing context segment header.")
        XCTAssertFalse(recorder.recordedContextFiles().isEmpty, "Context files should be sent to Codex client.")
    }

    /// Minimal reproduction isolating WorkspaceViewModel.askCodex + CodexService with real files.
    func test_minimal_workspace_vm_ask_records_context_segments() async throws {
        let log = TraceLog()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("repro-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileA = root.appendingPathComponent("a.swift")
        let fileB = root.appendingPathComponent("b.swift")
        try "aaa".write(to: fileA, atomically: true, encoding: .utf8)
        try "bbb".write(to: fileB, atomically: true, encoding: .utf8)

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
        _ = try await workspaceEngine.openWorkspace(rootPath: root.path)

        let recorder = TraceRecordingCodexClient()
        let codex = CodexService(
            conversationEngine: FakeConversationEngine(),
            workspaceEngine: workspaceEngine,
            codexClient: recorder.client(),
            fileLoader: FileContentLoaderAdapter(),
            retryPolicy: RetryPolicyImpl(),
            mutationAuthority: FakeMutationAuthority()
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
        workspaceVM.setSelectedURL(fileA)
        try await Task.sleep(nanoseconds: 50_000_000)

        let convo = Conversation()
        _ = await workspaceVM.askCodex("Explain", for: convo)

        let userPrompt = recorder.recordedMessages().last?.text ?? ""
        log.add("User prompt:\n\(userPrompt)")
        log.add("Context files:\(recorder.recordedContextFiles().map { $0.url.lastPathComponent })")
        log.flush()

        XCTAssertTrue(userPrompt.contains("## Context Segment 1"), "Prompt missing context segment header.")
        XCTAssertFalse(recorder.recordedContextFiles().isEmpty, "Expected at least one context file.")
    }

    // MARK: - Helpers
    private func lastAssistantText(_ convo: Conversation) -> String {
        convo.messages.last { $0.role == .assistant }?.text ?? ""
    }
}

// MARK: - Trace utilities
private final class TraceLog {
    private var lines: [String] = []
    func add(_ line: String) { lines.append(line) }
    func flush() {
        let payload = lines.joined(separator: "\n")
        XCTContext.runActivity(named: "AskCodex trace") { _ in
            print(payload)
        }
    }
}

@MainActor
private final class TracingWorkspaceProxy: ConversationWorkspaceHandling {
    private let inner: WorkspaceViewModel
    private let log: TraceLog

    init(inner: WorkspaceViewModel, log: TraceLog) {
        self.inner = inner
        self.log = log
    }

    func sendMessage(_ text: String, for conversation: Conversation) async {
        log.add("WorkspaceProxy.sendMessage text='\(text)' convo=\(conversation.id)")
        await inner.sendMessage(text, for: conversation)
    }

    func askCodex(_ text: String, for conversation: Conversation) async -> Conversation {
        let scope = inner.currentWorkspaceScope()
        let descriptorCount = inner.workspaceSnapshot.descriptors.count
        log.add(
            "WorkspaceProxy.askCodex scope=\(String(describing: scope)) "
            + "selectedDescriptorID=\(String(describing: inner.selectedDescriptorID)) "
            + "descriptors=\(descriptorCount)"
        )
        let result = await inner.askCodex(text, for: conversation)
        log.add("WorkspaceProxy.askCodex lastContextSnapshot nil? \(inner.lastContextSnapshot == nil)")
        if let snapshot = inner.lastContextSnapshot {
            let included = snapshot.includedFiles.map { $0.path }
            let segments = snapshot.segments.map { $0.totalBytes }
            log.add("Snapshot hash=\(String(describing: snapshot.snapshotHash)) included=\(included) segments=\(segments)")
        }
        return result
    }

    func setContextScope(_ scope: ContextScopeChoice) {
        inner.setContextScope(scope)
    }

    func setModelChoice(_ model: ModelChoice) {
        inner.setModelChoice(model)
    }

    func canAskCodex() -> Bool { inner.canAskCodex() }
}

// Reuse NoopWatcher for workspace engine
private final class NoopWatcher: FileSystemWatching {
    func watch(rootPath: String) -> AsyncStream<Void> { AsyncStream { _ in } }
}

private final class TraceRecordingCodexClient {
    private let queue = DispatchQueue(label: "trace-codex-client")
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
