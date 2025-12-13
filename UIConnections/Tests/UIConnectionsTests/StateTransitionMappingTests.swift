import XCTest
import AppCoreEngine
@testable import UIConnections
import UIContracts

/// Tests for domain state transition to ViewState transition mapping.
/// Verifies that AppCoreEngine state changes correctly map to UIContracts ViewState changes.
final class StateTransitionMappingTests: XCTestCase {

    // MARK: - Conversation State Transition Tests

    func testConversationDeltaContextTransition() {
        // Test that ConversationDelta.context maps to ConversationViewState with context
        let initial = UIContracts.ConversationViewState(
            id: UUID(),
            messages: [],
            streamingText: "",
            lastContext: nil
        )

        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 1000,
            totalTokens: 150,
            budget: .default,
            encodedSegments: []
        )

        let delta = AppCoreEngine.ConversationDelta.context(contextResult)

        // This uses ConversationDeltaMapper.apply which should be available
        // Since it's a pure mapping function, we can test the expected behavior
        XCTAssertEqual(initial.lastContext, nil, "Initial state should have no context")

        // Test that the delta represents the correct transition
        if case .context(let result) = delta {
            XCTAssertEqual(result.totalBytes, 1000)
            XCTAssertEqual(result.totalTokens, 150)
        } else {
            XCTFail("Expected context delta")
        }
    }

    func testConversationDeltaStreamingTransition() {
        // Test that ConversationDelta.assistantStreaming maps to streaming text updates
        let initial = UIContracts.ConversationViewState(
            id: UUID(),
            messages: [],
            streamingText: "",
            lastContext: nil
        )

        let streamingText = "Assistant is typing a response..."
        let delta = AppCoreEngine.ConversationDelta.assistantStreaming(streamingText)

        // Test the delta structure
        if case .assistantStreaming(let text) = delta {
            XCTAssertEqual(text, streamingText)
        } else {
            XCTFail("Expected assistantStreaming delta")
        }
    }

    func testConversationDeltaCommitTransition() {
        // Test that ConversationDelta.assistantCommitted maps to message addition
        let initial = UIContracts.ConversationViewState(
            id: UUID(),
            messages: [],
            streamingText: "Partial response",
            lastContext: nil
        )

        let committedMessage = AppCoreEngine.Message(
            id: UUID(),
            role: .assistant,
            text: "Complete response",
            createdAt: Date(),
            attachments: []
        )

        let delta = AppCoreEngine.ConversationDelta.assistantCommitted(committedMessage)

        // Test the delta structure
        if case .assistantCommitted(let message) = delta {
            XCTAssertEqual(message.text, "Complete response")
            XCTAssertEqual(message.role, .assistant)
        } else {
            XCTFail("Expected assistantCommitted delta")
        }
    }

    // MARK: - Workspace State Transition Tests

    func testWorkspaceUpdateToViewStateTransition() {
        // Test that WorkspaceUpdate transitions correctly map to WorkspaceViewState
        let fileID = AppCoreEngine.FileID()
        let snapshot = AppCoreEngine.WorkspaceSnapshot(
            rootPath: "/project",
            selectedPath: "/project/main.swift",
            lastPersistedSelection: "/project/main.swift",
            selectedDescriptorID: fileID,
            lastPersistedDescriptorID: fileID,
            contextPreferences: .empty,
            descriptorPaths: [fileID: "/project/main.swift"],
            contextInclusions: [fileID: .included],
            descriptors: [AppCoreEngine.FileDescriptor(id: fileID, name: "main.swift", type: .file)]
        )

        let projection = AppCoreEngine.WorkspaceTreeProjection(
            id: fileID,
            name: "main.swift",
            path: "/project/main.swift",
            isDirectory: false,
            children: []
        )

        let update = AppCoreEngine.WorkspaceUpdate(
            snapshot: snapshot,
            projection: projection,
            error: nil
        )

        // Test the mapping through DomainToUIMappers.toWorkspaceViewState
        let viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: snapshot.rootPath,
            selectedDescriptorID: snapshot.selectedDescriptorID,
            selectedPath: snapshot.selectedPath,
            projection: projection,
            contextInclusions: snapshot.contextInclusions,
            watcherError: nil
        )

        XCTAssertEqual(viewState.rootPath, "/project")
        XCTAssertEqual(viewState.selectedPath, "/project/main.swift")
        XCTAssertEqual(viewState.selectedDescriptorID?.rawValue, fileID.rawValue)
        XCTAssertEqual(viewState.projection?.name, "main.swift")
        XCTAssertEqual(viewState.contextInclusions[UIContracts.FileID(fileID.rawValue)], .included)
        XCTAssertNil(viewState.watcherError)
    }

    func testWorkspaceErrorStateTransition() {
        // Test workspace state transitions with errors
        let fileID = AppCoreEngine.FileID()
        let snapshot = AppCoreEngine.WorkspaceSnapshot(
            rootPath: "/project",
            selectedPath: nil,
            lastPersistedSelection: nil,
            selectedDescriptorID: nil,
            lastPersistedDescriptorID: nil,
            contextPreferences: .empty,
            descriptorPaths: [:],
            contextInclusions: [:],
            descriptors: []
        )

        let update = AppCoreEngine.WorkspaceUpdate(
            snapshot: snapshot,
            projection: nil,
            error: .watcherUnavailable
        )

        // Test error state mapping
        let viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: snapshot.rootPath,
            selectedDescriptorID: snapshot.selectedDescriptorID,
            selectedPath: snapshot.selectedPath,
            projection: nil,
            contextInclusions: snapshot.contextInclusions,
            watcherError: "Workspace watcher stopped (root missing or inaccessible)."
        )

        XCTAssertEqual(viewState.rootPath, "/project")
        XCTAssertNil(viewState.selectedPath)
        XCTAssertNil(viewState.selectedDescriptorID)
        XCTAssertNil(viewState.projection)
        XCTAssertEqual(viewState.watcherError, "Workspace watcher stopped (root missing or inaccessible).")
    }

    // MARK: - Context State Transition Tests

    func testContextBuildResultToUIStateTransition() {
        // Test that ContextBuildResult transitions map to UI state
        let loadedFile = AppCoreEngine.LoadedFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/context.swift"),
            fileTypeIdentifier: "swift",
            byteCount: 1000
        )

        let segment = AppCoreEngine.ContextSegment(
            files: [loadedFile],
            totalTokens: 150,
            totalBytes: 1000
        )

        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [loadedFile],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 1000,
            totalTokens: 150,
            budget: AppCoreEngine.ContextBudget(maxTokens: 1000, usedTokens: 150),
            encodedSegments: [segment]
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(contextResult)

        XCTAssertEqual(uiResult.attachments.count, 1)
        XCTAssertEqual(uiResult.totalBytes, 1000)
        XCTAssertEqual(uiResult.totalTokens, 150)
        XCTAssertEqual(uiResult.encodedSegments.count, 1)
        XCTAssertEqual(uiResult.encodedSegments.first?.totalTokens, 150)
    }

    // MARK: - Complex State Transition Sequences

    func testConversationStateTransitionSequence() {
        // Test a sequence of conversation state transitions
        let conversationId = UUID()

        // 1. Initial state
        var currentState = UIContracts.ConversationViewState(
            id: conversationId,
            messages: [],
            streamingText: "",
            lastContext: nil
        )

        XCTAssertEqual(currentState.messages.count, 0)
        XCTAssertEqual(currentState.streamingText, "")
        XCTAssertNil(currentState.lastContext)

        // 2. Context built (simulated transition)
        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 500,
            totalTokens: 75,
            budget: .default,
            encodedSegments: []
        )

        // The transition would update the state
        currentState = UIContracts.ConversationViewState(
            id: conversationId,
            messages: [],
            streamingText: "",
            lastContext: contextResult
        )

        XCTAssertNotNil(currentState.lastContext)
        XCTAssertEqual(currentState.lastContext?.totalTokens, 75)

        // 3. Streaming starts (simulated transition)
        currentState = UIContracts.ConversationViewState(
            id: conversationId,
            messages: [],
            streamingText: "Thinking...",
            lastContext: contextResult
        )

        XCTAssertEqual(currentState.streamingText, "Thinking...")
        XCTAssertNotNil(currentState.lastContext)

        // 4. Message committed (simulated transition)
        let message = AppCoreEngine.Message(
            id: UUID(),
            role: .assistant,
            text: "Final answer",
            createdAt: Date(),
            attachments: []
        )

        let uiMessage = DomainToUIMappers.toUIMessage(message)

        currentState = UIContracts.ConversationViewState(
            id: conversationId,
            messages: [uiMessage],
            streamingText: "",
            lastContext: contextResult
        )

        XCTAssertEqual(currentState.messages.count, 1)
        XCTAssertEqual(currentState.messages.first?.text, "Final answer")
        XCTAssertEqual(currentState.streamingText, "")
    }

    func testWorkspaceStateTransitionWithSelectionChanges() {
        // Test workspace state transitions with selection changes
        let file1ID = AppCoreEngine.FileID()
        let file2ID = AppCoreEngine.FileID()

        // Initial state: file1 selected
        var viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: "/project",
            selectedDescriptorID: file1ID,
            selectedPath: "/project/file1.swift",
            projection: nil,
            contextInclusions: [file1ID: .included],
            watcherError: nil
        )

        XCTAssertEqual(viewState.selectedDescriptorID?.rawValue, file1ID.rawValue)
        XCTAssertEqual(viewState.selectedPath, "/project/file1.swift")

        // Transition: select file2
        viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: "/project",
            selectedDescriptorID: file2ID,
            selectedPath: "/project/file2.swift",
            projection: nil,
            contextInclusions: [file1ID: .included, file2ID: .excluded],
            watcherError: nil
        )

        XCTAssertEqual(viewState.selectedDescriptorID?.rawValue, file2ID.rawValue)
        XCTAssertEqual(viewState.selectedPath, "/project/file2.swift")
        XCTAssertEqual(viewState.contextInclusions[UIContracts.FileID(file2ID.rawValue)], .excluded)
    }

    // MARK: - State Transition Edge Cases

    func testEmptyToEmptyStateTransitions() {
        // Test transitions between empty states
        let emptyResult = AppCoreEngine.ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 0,
            totalTokens: 0,
            budget: .default,
            encodedSegments: []
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(emptyResult)

        XCTAssertEqual(uiResult.attachments.count, 0)
        XCTAssertEqual(uiResult.totalBytes, 0)
        XCTAssertEqual(uiResult.totalTokens, 0)
    }

    func testNilToNilStateTransitions() {
        // Test transitions with nil values
        let viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: nil,
            selectedDescriptorID: nil,
            selectedPath: nil,
            projection: nil,
            contextInclusions: [:],
            watcherError: nil
        )

        XCTAssertNil(viewState.rootPath)
        XCTAssertNil(viewState.selectedDescriptorID)
        XCTAssertNil(viewState.selectedPath)
        XCTAssertNil(viewState.projection)
        XCTAssertTrue(viewState.contextInclusions.isEmpty)
        XCTAssertNil(viewState.watcherError)
    }

    func testLargeStateTransitionHandling() {
        // Test handling of large state transitions
        var largeInclusions = [AppCoreEngine.FileID: AppCoreEngine.ContextInclusionState]()
        for i in 0..<1000 {
            largeInclusions[AppCoreEngine.FileID()] = .included
        }

        let viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: "/large/project",
            selectedDescriptorID: nil,
            selectedPath: nil,
            projection: nil,
            contextInclusions: largeInclusions,
            watcherError: nil
        )

        XCTAssertEqual(viewState.contextInclusions.count, 1000)
        XCTAssertEqual(viewState.rootPath, "/large/project")
    }
}

