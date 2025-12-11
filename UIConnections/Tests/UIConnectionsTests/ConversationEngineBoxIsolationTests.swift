import XCTest
import AppCoreEngine
@testable import UIConnections

private final class ForwardingConversationBox: ConversationStreaming {
    let base: FakeConversationEngine
    init(base: FakeConversationEngine) { self.base = base }
    
    func conversation(for url: URL) async -> Conversation? { await base.conversation(for: url) }
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? { await base.conversation(forDescriptorIDs: ids) }
    func ensureConversation(for url: URL) async throws -> Conversation { try await base.ensureConversation(for: url) }
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation {
        try await base.ensureConversation(forDescriptorIDs: ids, pathResolver: pathResolver)
    }
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {
        try await base.updateContextDescriptors(for: conversationID, descriptorIDs: descriptorIDs)
    }
    func sendMessage(
        _ text: String,
        in conversation: Conversation,
        context: ConversationContextRequest?,
        onStream: ((ConversationDelta) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult) {
        try await base.sendMessage(text, in: conversation, context: context, onStream: onStream)
    }
}

@MainActor
final class ConversationEngineBoxIsolationTests: XCTestCase {
    func testBoxForwardsCallsWithoutConcreteEngineDependency() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let workspaceEngine = DeterministicWorkspaceEngine(
            root: root,
            files: [TestWorkspaceFile(relativePath: "file.swift", content: "body")],
            initialSelection: "file.swift"
        )
        let fakeEngine = FakeConversationEngine()
        let box = ForwardingConversationBox(base: fakeEngine)
        let viewModel = WorkspaceViewModel(
            workspaceEngine: workspaceEngine,
            conversationEngine: box,
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: FakeCodexService()
        )
        workspaceEngine.emitUpdate()
        await Task.yield()
        if let id = workspaceEngine.currentSnapshot.selectedDescriptorID {
            viewModel.setSelectedDescriptorID(id)
            await Task.yield()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        
        await viewModel.ensureConversation(for: root.appendingPathComponent("file.swift"))
        XCTAssertFalse(fakeEngine.ensureCalls.isEmpty)
        
        await viewModel.sendMessage("hi", for: Conversation())
        XCTAssertEqual(fakeEngine.sendCalls.last?.text, "hi")
    }
    
    func testUIConnectionsOperatesOnBoxProtocolOnly() {
        let fakeEngine = FakeConversationEngine()
        let box = ForwardingConversationBox(base: fakeEngine)
        XCTAssertNotNil(box as ConversationStreaming)
    }
}
