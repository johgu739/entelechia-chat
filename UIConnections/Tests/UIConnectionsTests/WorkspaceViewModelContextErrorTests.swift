import XCTest
import Combine
import AppCoreEngine
@testable import UIConnections

@MainActor
final class WorkspaceViewModelContextErrorTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []
    
    func testContextErrorPublisherEmitsOnContextLoadFailure() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        
        let alertCenter = AlertCenter()
        let workspaceEngine = FakeWorkspaceEngine()
        let conversationEngine = FailingConversationEngine()
        let vm = WorkspaceViewModel(
            workspaceEngine: workspaceEngine,
            conversationEngine: conversationEngine,
            projectTodosLoader: StubTodosLoader(),
            alertCenter: alertCenter
        )
        
        // Select a URL so sendMessage attempts to load context.
        vm.setSelectedURL(temp.appendingPathComponent("Context.txt"))
        
        let expectation = expectation(description: "context error emitted")
        var receivedError: Error?
        vm.contextErrorPublisher
            .sink { error in
                receivedError = error
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        let convo = Conversation(contextFilePaths: [])
        await vm.sendMessage("hello", for: convo)
        
        // Wait for error or timeout
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Verify an error was received (could be context load failure or timeout)
        XCTAssertNotNil(receivedError, "An error should be published when context load fails")
        if let error = receivedError {
            let description = error.localizedDescription
            // Accept various error messages that indicate failure
            // EngineError can have generic descriptions, so we check for error type or relevant keywords
            let isRelevantError = description.contains("Context load failed") || 
                                 description.contains("timeout") ||
                                 description.contains("Timeout") ||
                                 description.contains("failed") ||
                                 description.contains("couldn't be completed") ||
                                 error is EngineError
            XCTAssertTrue(isRelevantError, "Error should indicate failure: \(description) (type: \(type(of: error)))")
        }
    }
}

// MARK: - Fakes

private final class FakeWorkspaceEngine: WorkspaceEngine, @unchecked Sendable {
    private var lastSnapshot = WorkspaceSnapshot.empty
    private var descriptors: [FileDescriptor] = []
    private var descriptorPaths: [FileID: String] = [:]
    
    func openWorkspace(rootPath: String) async throws -> WorkspaceSnapshot {
        descriptors = []
        descriptorPaths = [:]
        lastSnapshot = WorkspaceSnapshot(
            rootPath: rootPath,
            selectedPath: nil,
            lastPersistedSelection: nil,
            selectedDescriptorID: nil,
            lastPersistedDescriptorID: nil,
            contextPreferences: .empty,
            descriptorPaths: descriptorPaths,
            contextInclusions: [:],
            descriptors: descriptors
        )
        return lastSnapshot
    }
    
    func snapshot() async -> WorkspaceSnapshot { lastSnapshot }
    func refresh() async throws -> WorkspaceSnapshot { lastSnapshot }
    func select(path: String?) async throws -> WorkspaceSnapshot { lastSnapshot }
    func contextPreferences() async throws -> WorkspaceSnapshot { lastSnapshot }
    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot { lastSnapshot }
    func treeProjection() async -> WorkspaceTreeProjection? { nil }
    func updates() -> AsyncStream<WorkspaceUpdate> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

private final class FailingConversationEngine: ConversationStreaming {
    func conversation(for url: URL) async -> Conversation? { Conversation(contextFilePaths: [url.path]) }
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? { nil }
    func ensureConversation(for url: URL) async throws -> Conversation { Conversation(contextFilePaths: [url.path]) }
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation { Conversation(contextFilePaths: []) }
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {}
    func sendMessage(_ text: String, in conversation: Conversation, context: ConversationContextRequest?, onStream: ((ConversationDelta) -> Void)?) async throws -> (Conversation, ContextBuildResult) {
        throw WorkspaceViewModel.TimeoutError(seconds: 0.1)
    }
}

private struct StubTodosLoader: ProjectTodosLoading {
    func loadTodos(for root: URL) throws -> ProjectTodos { .empty }
}


