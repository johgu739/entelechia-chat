import XCTest
import SwiftUI
@testable import ChatUI
import UIContracts

/// Contract tests for ViewState snapshots.
/// Tests that ViewState structs can be created, compared, and used correctly with various configurations.
@MainActor
final class ViewStateSnapshotTests: XCTestCase {

    // MARK: - ChatViewState Snapshot Tests

    func testChatViewStateEmptySnapshot() {
        // Test ChatViewState with empty/default values
        let state = UIContracts.ChatViewState(
            text: "",
            messages: [],
            streamingText: nil,
            isSending: false,
            isAsking: false,
            model: .codex,
            contextScope: .selection
        )

        XCTAssertEqual(state.text, "", "Should have empty text")
        XCTAssertTrue(state.messages.isEmpty, "Should have no messages")
        XCTAssertNil(state.streamingText, "Should have no streaming text")
        XCTAssertFalse(state.isSending, "Should not be sending")
        XCTAssertFalse(state.isAsking, "Should not be asking")
        XCTAssertEqual(state.model, .codex, "Should have codex model")
        XCTAssertEqual(state.contextScope, .selection, "Should have selection scope")
    }

    func testChatViewStateWithMessagesSnapshot() {
        // Test ChatViewState with populated messages
        let userMessage = UIContracts.UIMessage(
            id: UUID(),
            role: .user,
            text: "Hello, assistant!",
            createdAt: Date()
        )

        let assistantMessage = UIContracts.UIMessage(
            id: UUID(),
            role: .assistant,
            text: "Hello! How can I help you?",
            createdAt: Date()
        )

        let state = UIContracts.ChatViewState(
            text: "Follow-up question",
            messages: [userMessage, assistantMessage],
            streamingText: "Assistant is typing...",
            isSending: false,
            isAsking: true,
            model: .stub,
            contextScope: .workspace
        )

        XCTAssertEqual(state.text, "Follow-up question", "Should have correct text")
        XCTAssertEqual(state.messages.count, 2, "Should have 2 messages")
        XCTAssertEqual(state.messages.first?.role, .user, "First message should be user")
        XCTAssertEqual(state.messages.last?.role, .assistant, "Last message should be assistant")
        XCTAssertEqual(state.streamingText, "Assistant is typing...", "Should have streaming text")
        XCTAssertFalse(state.isSending, "Should not be sending")
        XCTAssertTrue(state.isAsking, "Should be asking")
        XCTAssertEqual(state.model, .stub, "Should have stub model")
        XCTAssertEqual(state.contextScope, .workspace, "Should have workspace scope")
    }

    func testChatViewStateEquatable() {
        // Test that ChatViewState conforms to Equatable correctly
        let state1 = UIContracts.ChatViewState(
            text: "test",
            messages: [],
            streamingText: nil,
            isSending: false,
            isAsking: false,
            model: .codex,
            contextScope: .selection
        )

        let state2 = UIContracts.ChatViewState(
            text: "test",
            messages: [],
            streamingText: nil,
            isSending: false,
            isAsking: false,
            model: .codex,
            contextScope: .selection
        )

        let state3 = UIContracts.ChatViewState(
            text: "different",
            messages: [],
            streamingText: nil,
            isSending: false,
            isAsking: false,
            model: .codex,
            contextScope: .selection
        )

        XCTAssertEqual(state1, state2, "Identical states should be equal")
        XCTAssertNotEqual(state1, state3, "Different states should not be equal")
    }

    // MARK: - WorkspaceUIViewState Snapshot Tests

    func testWorkspaceUIViewStateEmptySnapshot() {
        // Test WorkspaceUIViewState with empty/default values
        let state = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        XCTAssertNil(state.selectedNode, "Should have no selected node")
        XCTAssertNil(state.selectedDescriptorID, "Should have no selected descriptor ID")
        XCTAssertNil(state.rootFileNode, "Should have no root file node")
        XCTAssertNil(state.rootDirectory, "Should have no root directory")
        XCTAssertEqual(state.projectTodos.allTodos.count, 0, "Should have no todos")
        XCTAssertNil(state.todosErrorDescription, "Should have no error description")
    }

    func testWorkspaceUIViewStateWithDataSnapshot() {
        // Test WorkspaceUIViewState with populated data
        let fileUUID = UUID()
        let fileID = UIContracts.FileID(fileUUID)
        let fileNode = UIContracts.FileNode(
            id: fileUUID,
            descriptorID: fileID,
            name: "test.swift",
            path: URL(fileURLWithPath: "/test.swift"),
            children: [],
            icon: "doc.text",
            isDirectory: false
        )

        let state = UIContracts.WorkspaceUIViewState(
            selectedNode: fileNode,
            selectedDescriptorID: fileID,
            rootFileNode: fileNode,
            rootDirectory: URL(fileURLWithPath: "/project"),
            projectTodos: UIContracts.ProjectTodos(
                allTodos: ["Fix bug in /test.swift:42"]
            ),
            todosErrorDescription: "Connection failed"
        )

        XCTAssertEqual(state.selectedNode?.name, "test.swift", "Should have correct selected node")
        XCTAssertEqual(state.selectedDescriptorID, fileID, "Should have correct descriptor ID")
        XCTAssertEqual(state.rootFileNode?.path.path, "/test.swift", "Should have correct root file node")
        XCTAssertEqual(state.rootDirectory?.path, "/project", "Should have correct root directory")
        XCTAssertEqual(state.projectTodos.allTodos.count, 1, "Should have 1 todo")
        XCTAssertEqual(state.todosErrorDescription, "Connection failed", "Should have error description")
    }

    func testWorkspaceUIViewStateEquatable() {
        // Test that WorkspaceUIViewState conforms to Equatable correctly
        let state1 = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let state2 = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let state3 = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: "error"
        )

        XCTAssertEqual(state1, state2, "Identical states should be equal")
        XCTAssertNotEqual(state1, state3, "Different states should not be equal")
    }

    // MARK: - ContextViewState Snapshot Tests

    func testContextViewStateEmptySnapshot() {
        // Test ContextViewState with empty/default values
        let state = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil
        )

        XCTAssertNil(state.lastContextSnapshot, "Should have no context snapshot")
        XCTAssertNil(state.lastContextResult, "Should have no context result")
        XCTAssertTrue(state.streamingMessages.isEmpty, "Should have no streaming messages")
        XCTAssertNil(state.bannerMessage, "Should have no banner message")
    }

    func testContextViewStateWithDataSnapshot() {
        // Test ContextViewState with populated data
        let contextSnapshot = UIContracts.ContextSnapshot(
            scope: .workspace,
            snapshotHash: "abc123",
            segments: [],
            includedFiles: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalTokens: 1000,
            totalBytes: 5000
        )

        let budget = UIContracts.ContextBudgetView(
            maxPerFileBytes: 32000,
            maxPerFileTokens: 8000,
            maxTotalBytes: 220000,
            maxTotalTokens: 60000
        )
        let contextResult = UIContracts.UIContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 5000,
            totalTokens: 1000,
            encodedSegments: [],
            budget: budget
        )

        let streamingMessages = [
            UUID(): "First part of response...",
            UUID(): "Second part of response..."
        ]

        let state = UIContracts.ContextViewState(
            lastContextSnapshot: contextSnapshot,
            lastContextResult: contextResult,
            streamingMessages: streamingMessages,
            bannerMessage: "Context built successfully"
        )

        XCTAssertEqual(state.lastContextSnapshot?.scope, .workspace, "Should have correct snapshot scope")
        XCTAssertEqual(state.lastContextResult?.totalTokens, 1000, "Should have correct result tokens")
        XCTAssertEqual(state.streamingMessages.count, 2, "Should have 2 streaming messages")
        XCTAssertEqual(state.bannerMessage, "Context built successfully", "Should have correct banner message")
    }

    func testContextViewStateEquatable() {
        // Test that ContextViewState conforms to Equatable correctly
        let state1 = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil
        )

        let state2 = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil
        )

        let state3 = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: "error"
        )

        XCTAssertEqual(state1, state2, "Identical states should be equal")
        XCTAssertNotEqual(state1, state3, "Different states should not be equal")
    }

    // MARK: - PresentationViewState Snapshot Tests

    func testPresentationViewStateSnapshot() {
        // Test PresentationViewState with various configurations
        let state1 = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        XCTAssertEqual(state1.activeNavigator, .project, "Should have project navigator")
        XCTAssertEqual(state1.filterText, "", "Should have empty filter")
        XCTAssertTrue(state1.expandedDescriptorIDs.isEmpty, "Should have no expanded IDs")

        let fileID = UIContracts.FileID()
        let state2 = UIContracts.PresentationViewState(
            activeNavigator: .search,
            filterText: "search term",
            expandedDescriptorIDs: [fileID]
        )

        XCTAssertEqual(state2.activeNavigator, .search, "Should have search navigator")
        XCTAssertEqual(state2.filterText, "search term", "Should have filter text")
        XCTAssertEqual(state2.expandedDescriptorIDs.count, 1, "Should have 1 expanded ID")
        XCTAssertTrue(state2.expandedDescriptorIDs.contains(fileID), "Should contain the file ID")
    }

    func testPresentationViewStateEquatable() {
        // Test that PresentationViewState conforms to Equatable correctly
        let state1 = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        let state2 = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        let state3 = UIContracts.PresentationViewState(
            activeNavigator: .search,
            filterText: "",
            expandedDescriptorIDs: []
        )

        XCTAssertEqual(state1, state2, "Identical states should be equal")
        XCTAssertNotEqual(state1, state3, "Different states should not be equal")
    }

    // MARK: - Combined ViewState Integration Tests

    func testCombinedViewStatesForChatView() {
        // Test that all ViewState types work together for ChatView
        let chatState = UIContracts.ChatViewState(
            text: "Hello",
            messages: [],
            streamingText: nil,
            isSending: false,
            isAsking: false,
            model: .codex,
            contextScope: .selection
        )

        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let contextState = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil
        )

        // Verify all states can be created and used together
        XCTAssertNotNil(chatState, "ChatViewState should be valid")
        XCTAssertNotNil(workspaceState, "WorkspaceUIViewState should be valid")
        XCTAssertNotNil(contextState, "ContextViewState should be valid")

        // Test that ChatView can be constructed with these combined states
        let inspectorTab = Binding<UIContracts.InspectorTab>(
            get: { .files },
            set: { _ in }
        )

        let view = ChatView(
            chatState: chatState,
            workspaceState: workspaceState,
            contextState: contextState,
            onChatIntent: { _ in },
            onWorkspaceIntent: { _ in },
            inspectorTab: inspectorTab
        )

        XCTAssertNotNil(view, "ChatView should construct with combined ViewStates")
    }

    func testCombinedViewStatesForNavigatorView() {
        // Test that ViewState types work together for XcodeNavigatorView
        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "test",
            expandedDescriptorIDs: []
        )

        // Verify states can be created and used together
        XCTAssertNotNil(workspaceState, "WorkspaceUIViewState should be valid")
        XCTAssertNotNil(presentationState, "PresentationViewState should be valid")

        // Test that XcodeNavigatorView can be constructed
        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should construct with combined ViewStates")
    }
}
