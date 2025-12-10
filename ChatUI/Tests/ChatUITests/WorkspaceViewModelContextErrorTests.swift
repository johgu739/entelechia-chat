import XCTest
import Combine
@testable import ChatUI
import UIConnections

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
        vm.contextErrorPublisher
            .sink { message in
                XCTAssertTrue(message.contains("Context load failed"))
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        let convo = Conversation(contextFilePaths: [])
        await vm.sendMessage("hello", for: convo)
        await fulfillment(of: [expectation], timeout: 5.0)
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
    
    func select(path: String?) async throws -> WorkspaceSnapshot {
        if let path {
            let id = FileID()
            descriptors = [FileDescriptor(id: id, name: (path as NSString).lastPathComponent, type: .file)]
            descriptorPaths = [id: path]
        }
        lastSnapshot = WorkspaceSnapshot(
            rootPath: lastSnapshot.rootPath,
            selectedPath: path,
            lastPersistedSelection: path,
            selectedDescriptorID: descriptorPaths.first?.key,
            lastPersistedDescriptorID: descriptorPaths.first?.key,
            contextPreferences: .empty,
            descriptorPaths: descriptorPaths,
            contextInclusions: descriptorPaths.reduce(into: [:]) { result, pair in
                result[pair.key] = .included
            },
            descriptors: descriptors
        )
        return lastSnapshot
    }
    
    func contextPreferences() async throws -> WorkspaceSnapshot { lastSnapshot }
    
    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot { lastSnapshot }
    
    func treeProjection() async -> WorkspaceTreeProjection? { nil }
    
    func updates() -> AsyncStream<WorkspaceUpdate> { AsyncStream { $0.finish() } }
}

private struct ThrowingFileLoader: FileContentLoading {
    func load(url: URL) async throws -> String {
        throw EngineError.contextLoadFailed("mock failure")
    }
}

private final class ThrowingCodexClient: CodexClient, @unchecked Sendable {
    typealias MessageType = Message
    typealias ContextFileType = LoadedFile
    typealias OutputPayload = ModelResponse
    
    func stream(
        messages: [Message],
        contextFiles: [LoadedFile]
    ) async throws -> AsyncThrowingStream<StreamChunk<ModelResponse>, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.done)
            continuation.finish()
        }
    }
}

private struct StubTodosLoader: ProjectTodosLoading {
    func loadTodos(for root: URL) throws -> ProjectTodos { .empty }
}

private struct FailingConversationEngine: ConversationStreaming {
    func conversation(for url: URL) async -> Conversation? { nil }
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? { nil }
    func ensureConversation(for url: URL) async throws -> Conversation { Conversation() }
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation { Conversation() }
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {}
    func sendMessage(_ text: String, in conversation: Conversation, context: ConversationContextRequest?, onStream: ((ConversationDelta) -> Void)?) async throws -> (Conversation, ContextBuildResult) {
        throw EngineError.contextLoadFailed("mock failure")
    }
}

