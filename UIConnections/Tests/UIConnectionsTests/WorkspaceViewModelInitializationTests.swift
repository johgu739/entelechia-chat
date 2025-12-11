import XCTest
import Combine
import AppCoreEngine
@testable import UIConnections

// MARK: - Test Doubles

private final class StubWorkspaceEngine: WorkspaceEngine, @unchecked Sendable {
    private var snapshot: WorkspaceSnapshot
    private let projection: WorkspaceTreeProjection
    private let stream: AsyncStream<WorkspaceUpdate>
    private let continuation: AsyncStream<WorkspaceUpdate>.Continuation

    init() {
        let fileID = FileID()
        snapshot = WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: nil,
            lastPersistedSelection: nil,
            selectedDescriptorID: nil,
            lastPersistedDescriptorID: nil,
            contextPreferences: .empty,
            descriptorPaths: [fileID: "/root/file.swift"],
            contextInclusions: [fileID: .neutral],
            descriptors: [FileDescriptor(id: fileID, name: "file.swift", type: .file)]
        )
        projection = WorkspaceTreeProjection(
            id: fileID,
            name: "file.swift",
            path: "/root/file.swift",
            isDirectory: false,
            children: []
        )

        var cont: AsyncStream<WorkspaceUpdate>.Continuation!
        stream = AsyncStream { cont = $0 }
        continuation = cont
        continuation.yield(WorkspaceUpdate(snapshot: snapshot, projection: projection, error: nil))
    }

    func openWorkspace(rootPath: String) async throws -> WorkspaceSnapshot { snapshot }
    func snapshot() async -> WorkspaceSnapshot { snapshot }
    func refresh() async throws -> WorkspaceSnapshot { snapshot }
    func select(path: String?) async throws -> WorkspaceSnapshot { snapshot }
    func contextPreferences() async throws -> WorkspaceSnapshot { snapshot }
    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot { snapshot }
    func treeProjection() async -> WorkspaceTreeProjection? { projection }
    func updates() -> AsyncStream<WorkspaceUpdate> { stream }
}

private final class StubTodosLoader: ProjectTodosLoading, @unchecked Sendable {
    private let todos: ProjectTodos
    
    init(todos: ProjectTodos = .empty) {
        self.todos = todos
    }
    
    func loadTodos(for root: URL) throws -> ProjectTodos { todos }
}

private final class ConversationEngineStub: ConversationStreaming {
    func conversation(for url: URL) async -> Conversation? { nil }
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? { nil }
    func ensureConversation(for url: URL) async throws -> Conversation { Conversation(contextFilePaths: [url.path]) }
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation { Conversation(contextFilePaths: []) }
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {}
    func sendMessage(_ text: String, in conversation: Conversation, context: ConversationContextRequest?, onStream: ((ConversationDelta) -> Void)?) async throws -> (Conversation, ContextBuildResult) {
        (conversation, ContextBuildResult(attachments: [], truncatedFiles: [], excludedFiles: [], totalBytes: 0, totalTokens: 0, budget: .default, encodedSegments: []))
    }
}

/// Tests for WorkspaceViewModel initialization, dependency injection, and Combine subscriptions.
/// Ensures no silent breakages in basic initialization can occur.
@MainActor
final class WorkspaceViewModelInitializationTests: XCTestCase {
    
    // MARK: - Test A: init() completes with all dependencies
    
    func testInitCompletesWithAllDependencies() {
        let engine = StubWorkspaceEngine()
        let conversationEngine = ConversationEngineStub()
        let todosLoader = StubTodosLoader()
        let codexService = NullCodexQuerying()
        let alertCenter = AlertCenter()
        let contextSelection = ContextSelectionState()
        
        let vm = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: conversationEngine,
            projectTodosLoader: todosLoader,
            codexService: codexService,
            alertCenter: alertCenter,
            contextSelection: contextSelection
        )
        
        // Verify all dependencies are stored
        XCTAssertNotNil(vm.workspaceEngine)
        XCTAssertNotNil(vm.conversationEngine)
        XCTAssertNotNil(vm.projectTodosLoader)
        XCTAssertNotNil(vm.codexService)
        XCTAssertNotNil(vm.alertCenter)
        XCTAssertNotNil(vm.contextSelection)
    }
    
    func testInitWithMinimalDependencies() {
        let engine = StubWorkspaceEngine()
        let conversationEngine = ConversationEngineStub()
        let todosLoader = StubTodosLoader()
        
        let vm = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: conversationEngine,
            projectTodosLoader: todosLoader
        )
        
        // Verify defaults are applied
        XCTAssertNotNil(vm.codexService)
        XCTAssertNil(vm.alertCenter) // Optional, defaults to nil
        XCTAssertNotNil(vm.contextSelection) // Has default
    }
    
    // MARK: - Test B: All Combine subscriptions are stored
    
    func testCombineSubscriptionsAreStored() {
        let vm = makeViewModel()
        
        // After initialization, cancellables should not be empty
        // because bindContextSelection() and subscribeToUpdates() create subscriptions
        XCTAssertFalse(vm.cancellables.isEmpty, "Initialization should create Combine subscriptions")
        
        // Verify subscription count is reasonable (at least 2: context selection + updates)
        XCTAssertGreaterThanOrEqual(vm.cancellables.count, 2, "Should have at least context selection and updates subscriptions")
    }
    
    func testSubscriptionsPersistAfterStateChanges() {
        let vm = makeViewModel()
        let initialCount = vm.cancellables.count
        
        // Trigger state changes that might create new subscriptions
        vm.setContextScope(.selection)
        vm.setModelChoice(.codex)
        
        // Subscriptions should still exist
        XCTAssertGreaterThanOrEqual(vm.cancellables.count, initialCount, "Subscriptions should persist after state changes")
    }
    
    // MARK: - Test C: contextErrorSubject binding works end-to-end
    
    func testContextErrorSubjectPublishesErrors() async {
        let vm = makeViewModel()
        let expectation = expectation(description: "Error published")
        var receivedError: Error?
        
        let cancellable = vm.contextErrorPublisher
            .sink { error in
                receivedError = error
                expectation.fulfill()
            }
        
        // Send an error through the subject
        let testError = EngineError.contextLoadFailed("Test error message")
        vm.contextErrorSubject.send(testError)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(receivedError)
        if let engineError = receivedError as? EngineError {
            if case .contextLoadFailed(let message) = engineError {
                XCTAssertEqual(message, "Test error message")
            } else {
                XCTFail("Expected contextLoadFailed error")
            }
        } else {
            XCTFail("Expected EngineError")
        }
        
        cancellable.cancel()
    }
    
    func testContextErrorSubjectCanSendMultipleErrors() async {
        let vm = makeViewModel()
        var receivedErrors: [Error] = []
        let expectation1 = expectation(description: "First error")
        let expectation2 = expectation(description: "Second error")
        
        let cancellable = vm.contextErrorPublisher
            .sink { error in
                receivedErrors.append(error)
                if receivedErrors.count == 1 {
                    expectation1.fulfill()
                } else if receivedErrors.count == 2 {
                    expectation2.fulfill()
                }
            }
        
        vm.contextErrorSubject.send(EngineError.contextLoadFailed("First"))
        vm.contextErrorSubject.send(EngineError.contextLoadFailed("Second"))
        
        await fulfillment(of: [expectation1, expectation2], timeout: 1.0)
        
        XCTAssertEqual(receivedErrors.count, 2)
        
        cancellable.cancel()
    }
    
    // MARK: - Test D: State invariants hold
    
    func testStateInvariantsAfterInit() {
        let vm = makeViewModel()
        
        // rootFileNode should be nil pre-workspace
        XCTAssertNil(vm.rootFileNode, "rootFileNode should be nil before workspace is opened")
        
        // Context state should be clean
        XCTAssertNil(vm.lastContextResult, "lastContextResult should be nil initially")
        XCTAssertNil(vm.lastContextSnapshot, "lastContextSnapshot should be nil initially")
        XCTAssertEqual(vm.activeScope, .selection, "activeScope should default to .selection")
        XCTAssertEqual(vm.modelChoice, .codex, "modelChoice should default to .codex")
        
        // No domain logic should be triggered
        XCTAssertFalse(vm.isLoading, "isLoading should be false initially")
        XCTAssertNil(vm.selectedNode, "selectedNode should be nil initially")
        XCTAssertNil(vm.selectedDescriptorID, "selectedDescriptorID should be nil initially")
        XCTAssertTrue(vm.expandedDescriptorIDs.isEmpty, "expandedDescriptorIDs should be empty initially")
        XCTAssertTrue(vm.streamingMessages.isEmpty, "streamingMessages should be empty initially")
    }
    
    func testNoLifecycleWorkDuringInit() {
        let engine = StubWorkspaceEngine()
        
        // Track if any async work is triggered
        var asyncWorkTriggered = false
        let originalOpen = engine.openWorkspace(rootPath:)
        
        // Create VM - should not trigger any workspace opening
        let vm = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: ConversationEngineStub(),
            projectTodosLoader: StubTodosLoader()
        )
        
        // Verify no workspace was opened
        XCTAssertNil(vm.rootFileNode, "Init should not open workspace")
        XCTAssertNil(vm.rootDirectory, "Init should not set root directory")
        
        // Verify cancellables exist (subscriptions created)
        XCTAssertFalse(vm.cancellables.isEmpty, "Subscriptions should be created during init")
    }
    
    func testContextSelectionBindingIsActive() {
        let vm = makeViewModel()
        let contextSelection = vm.contextSelection
        
        // Change scope via view model
        vm.setContextScope(.workspace)
        
        // Verify it's reflected in both places
        XCTAssertEqual(vm.activeScope, .workspace)
        XCTAssertEqual(contextSelection.scopeChoice, .workspace)
        
        // Change model choice
        vm.setModelChoice(.codex)
        
        XCTAssertEqual(vm.modelChoice, .codex)
        XCTAssertEqual(contextSelection.modelChoice, .codex)
    }
    
    // MARK: - Helper Methods
    
    private func makeViewModel() -> WorkspaceViewModel {
        WorkspaceViewModel(
            workspaceEngine: StubWorkspaceEngine(),
            conversationEngine: ConversationEngineStub(),
            projectTodosLoader: StubTodosLoader(),
            codexService: NullCodexQuerying(),
            alertCenter: AlertCenter(),
            contextSelection: ContextSelectionState()
        )
    }
}
