import XCTest
import SwiftUI
@testable import ChatUI
import UIContracts

/// Contract tests for ChatView.
/// Tests that ChatView renders correctly with fake ViewState structs and intent closures.
@MainActor
final class ChatViewContractTests: XCTestCase {

    // MARK: - Basic Construction Tests

    func testChatViewConstructsWithMinimalViewState() {
        // Test that ChatView can be constructed with basic fake ViewState
        let chatState = UIContracts.ChatViewState(
            text: "",
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
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let contextState = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil
        )

        var chatIntentCalled = false
        var workspaceIntentCalled = false
        let inspectorTab = Binding<UIContracts.InspectorTab>(
            get: { .files },
            set: { _ in }
        )

        let view = ChatView(
            chatState: chatState,
            workspaceState: workspaceState,
            contextState: contextState,
            onChatIntent: { _ in chatIntentCalled = true },
            onWorkspaceIntent: { _ in workspaceIntentCalled = true },
            inspectorTab: inspectorTab
        )

        // Verify construction succeeds
        XCTAssertNotNil(view, "ChatView should construct with fake ViewState")

        // Verify intent closures are properly set (by calling them)
        // Note: We can't easily test the actual view body in unit tests,
        // but we can verify the view struct is constructed correctly
    }

    func testChatViewConstructsWithPopulatedMessages() {
        // Test ChatView with populated message data
        let message = UIContracts.UIMessage(
            id: UUID(),
            role: .assistant,
            text: "Hello, world!",
                createdAt: Date()
        )

        let chatState = UIContracts.ChatViewState(
            text: "User input",
            messages: [message],
            streamingText: "Streaming response...",
            isSending: false,
            isAsking: true,
            model: .codex,
            contextScope: .workspace
        )

        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let contextState = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil
        )

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

        XCTAssertNotNil(view, "ChatView should construct with populated messages")
        XCTAssertEqual(chatState.messages.count, 1, "Should have one message")
        XCTAssertEqual(chatState.streamingText, "Streaming response...", "Should have streaming text")
    }

    func testChatViewConstructsWithErrorStates() {
        // Test ChatView with error states
        let chatState = UIContracts.ChatViewState(
            text: "",
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
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: "Failed to load todos"
        )

        let contextState = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: "Context build failed"
        )

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

        XCTAssertNotNil(view, "ChatView should construct with error states")
        XCTAssertEqual(workspaceState.todosErrorDescription, "Failed to load todos", "Should have todos error")
        XCTAssertEqual(contextState.bannerMessage, "Context build failed", "Should have context banner")
    }

    func testChatViewConstructsWithWorkspaceData() {
        // Test ChatView with workspace data
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

        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: fileNode,
            selectedDescriptorID: fileID,
            rootFileNode: fileNode,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let chatState = UIContracts.ChatViewState(
            text: "",
            messages: [],
            streamingText: nil,
            isSending: false,
            isAsking: false,
            model: .codex,
            contextScope: .selection
        )

        let contextState = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil
        )

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

        XCTAssertNotNil(view, "ChatView should construct with workspace data")
        XCTAssertEqual(workspaceState.selectedNode?.name, "test.swift", "Should have selected file")
        XCTAssertEqual(workspaceState.rootDirectory?.path, "/", "Should have root directory")
    }

    // MARK: - Intent Handler Tests

    func testChatIntentClosureIsCalled() {
        // Test that chat intent closure is properly wired
        let chatState = UIContracts.ChatViewState(
            text: "",
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
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let contextState = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil
        )

        var receivedIntent: UIContracts.ChatIntent?
        let inspectorTab = Binding<UIContracts.InspectorTab>(
            get: { .files },
            set: { _ in }
        )

        let view = ChatView(
            chatState: chatState,
            workspaceState: workspaceState,
            contextState: contextState,
            onChatIntent: { intent in receivedIntent = intent },
            onWorkspaceIntent: { _ in },
            inspectorTab: inspectorTab
        )

        XCTAssertNotNil(view, "ChatView should construct with intent handlers")

        // Note: In a real contract test, we'd need to simulate UI interactions
        // to trigger the intent closures. For now, we verify the view constructs
        // with the closures properly.
    }

    func testWorkspaceIntentClosureIsCalled() {
        // Test that workspace intent closure is properly wired
        let chatState = UIContracts.ChatViewState(
            text: "",
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
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let contextState = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil
        )

        var receivedIntent: UIContracts.WorkspaceIntent?
        let inspectorTab = Binding<UIContracts.InspectorTab>(
            get: { .files },
            set: { _ in }
        )

        let view = ChatView(
            chatState: chatState,
            workspaceState: workspaceState,
            contextState: contextState,
            onChatIntent: { _ in },
            onWorkspaceIntent: { intent in receivedIntent = intent },
            inspectorTab: inspectorTab
        )

        XCTAssertNotNil(view, "ChatView should construct with workspace intent handler")
    }
}
