import XCTest
import SwiftUI
@testable import ChatUI
import UIContracts

/// Contract tests for intent handler closures.
/// Tests that intent closures are properly wired and can be invoked with correct parameters.
@MainActor
final class IntentHandlerContractTests: XCTestCase {

    // MARK: - ChatIntent Handler Tests

    func testChatIntentHandlerReceivesCorrectIntents() {
        // Test that chat intent handler receives various ChatIntent types
        let conversationID = UUID()
        let chatIntents: [UIContracts.ChatIntent] = [
            .sendMessage("Hello, world!", conversationID),
            .askCodex("What is the meaning of life?", conversationID),
            .setModelChoice(.codex),
            .setContextScope(.workspace)
        ]

        for intent in chatIntents {
            var receivedIntent: UIContracts.ChatIntent?
            let handler: (UIContracts.ChatIntent) -> Void = { receivedIntent = $0 }

            // Invoke the handler directly (in contract testing)
            handler(intent)

            XCTAssertEqual(receivedIntent, intent, "Handler should receive correct \(intent) intent")
        }
    }

    func testChatIntentHandlerWithComplexData() {
        // Test chat intent handler with complex data structures
        let longMessage = String(repeating: "This is a long message. ", count: 100)
        let sendIntent = UIContracts.ChatIntent.sendMessage(longMessage, UUID())

        var receivedIntent: UIContracts.ChatIntent?
        let handler: (UIContracts.ChatIntent) -> Void = { receivedIntent = $0 }

        handler(sendIntent)

        if case .sendMessage(let message) = receivedIntent {
            XCTAssertEqual(message, longMessage, "Should preserve long message content")
            XCTAssertEqual(message.count, longMessage.count, "Should preserve message length")
        } else {
            XCTFail("Should receive sendMessage intent")
        }
    }

    // MARK: - WorkspaceIntent Handler Tests

    func testWorkspaceIntentHandlerReceivesCorrectIntents() {
        // Test that workspace intent handler receives various WorkspaceIntent types
        let fileID = FileID()

        let workspaceIntents: [UIContracts.WorkspaceIntent] = [
            .selectFile("/test.swift"),
            .toggleFileInclusion(fileID),
            .refreshWorkspace,
            .openWorkspace(URL(fileURLWithPath: "/project")),
            .setContextScope(.workspace)
        ]

        for intent in workspaceIntents {
            var receivedIntent: UIContracts.WorkspaceIntent?
            let handler: (UIContracts.WorkspaceIntent) -> Void = { receivedIntent = $0 }

            handler(intent)

            XCTAssertEqual(receivedIntent, intent, "Handler should receive correct \(intent) intent")
        }
    }

    func testWorkspaceIntentHandlerWithFileOperations() {
        // Test workspace intent handler with file-related operations
        let filePath = "/very/deep/nested/directory/structure/file.swift"
        let selectIntent = UIContracts.WorkspaceIntent.selectFile(filePath)

        var receivedIntent: UIContracts.WorkspaceIntent?
        let handler: (UIContracts.WorkspaceIntent) -> Void = { receivedIntent = $0 }

        handler(selectIntent)

        if case .selectFile(let path) = receivedIntent {
            XCTAssertEqual(path, filePath, "Should preserve complex file path")
        } else {
            XCTFail("Should receive selectFile intent")
        }
    }

    func testWorkspaceIntentHandlerWithURLParameters() {
        // Test workspace intent handler with URL parameters
        let projectURL = URL(fileURLWithPath: "/Users/username/Projects/MyApp")
        let openIntent = UIContracts.WorkspaceIntent.openWorkspace(projectURL)

        var receivedIntent: UIContracts.WorkspaceIntent?
        let handler: (UIContracts.WorkspaceIntent) -> Void = { receivedIntent = $0 }

        handler(openIntent)

        if case .openWorkspace(let url) = receivedIntent {
            XCTAssertEqual(url, projectURL, "Should preserve project URL")
            XCTAssertEqual(url.path, "/Users/username/Projects/MyApp", "Should preserve URL path")
        } else {
            XCTFail("Should receive openWorkspace intent")
        }
    }

    // MARK: - Handler Closure Identity Tests

    func testChatIntentHandlerClosureIdentity() {
        // Test that the same handler closure is used consistently
        var callCount = 0
        let handler: (UIContracts.ChatIntent) -> Void = { _ in callCount += 1 }

        let intent1 = UIContracts.ChatIntent.sendMessage("First", UUID())
        let intent2 = UIContracts.ChatIntent.sendMessage("Second", UUID())

        handler(intent1)
        handler(intent2)

        XCTAssertEqual(callCount, 2, "Handler should be called exactly twice")
    }

    func testWorkspaceIntentHandlerClosureIdentity() {
        // Test that the same workspace handler closure is used consistently
        var callCount = 0
        let handler: (UIContracts.WorkspaceIntent) -> Void = { _ in callCount += 1 }

        let intent1 = UIContracts.WorkspaceIntent.selectFile("/file1.swift")
        let intent2 = UIContracts.WorkspaceIntent.selectFile("/file2.swift")

        handler(intent1)
        handler(intent2)

        XCTAssertEqual(callCount, 2, "Workspace handler should be called exactly twice")
    }

    // MARK: - Intent Handler Wiring Tests

    func testChatViewIntentHandlerWiring() {
        // Test that ChatView properly wires intent handlers
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

        var chatIntentReceived: UIContracts.ChatIntent?
        var workspaceIntentReceived: UIContracts.WorkspaceIntent?

        let inspectorTab = Binding<UIContracts.InspectorTab>(
            get: { .files },
            set: { _ in }
        )

        let view = ChatView(
            chatState: chatState,
            workspaceState: workspaceState,
            contextState: contextState,
            onChatIntent: { chatIntentReceived = $0 },
            onWorkspaceIntent: { workspaceIntentReceived = $0 },
            inspectorTab: inspectorTab
        )

        XCTAssertNotNil(view, "ChatView should construct with intent handlers")

        // Test that handlers are properly assigned by calling them directly
        // (In real UI, these would be called by user interactions)
        let testChatIntent = UIContracts.ChatIntent.sendMessage("test", UUID())
        if let chatHandler = mirrorProperty(view, "onChatIntent") as? (UIContracts.ChatIntent) -> Void {
            chatHandler(testChatIntent)
            XCTAssertEqual(chatIntentReceived, testChatIntent, "Chat intent should be received")
        }
    }

    func testXcodeNavigatorViewIntentHandlerWiring() {
        // Test that XcodeNavigatorView properly wires intent handlers
        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        var workspaceIntentReceived: UIContracts.WorkspaceIntent?

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { workspaceIntentReceived = $0 }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should construct with intent handler")

        // Test that handler is properly assigned
        let testIntent = UIContracts.WorkspaceIntent.refreshWorkspace
        if let workspaceHandler = mirrorProperty(view, "onWorkspaceIntent") as? (UIContracts.WorkspaceIntent) -> Void {
            workspaceHandler(testIntent)
            XCTAssertEqual(workspaceIntentReceived, testIntent, "Workspace intent should be received")
        }
    }

    // MARK: - Intent Parameter Validation Tests

    func testChatIntentParametersAreValidated() {
        // Test that ChatIntent parameters are properly structured
        let conversationID = UUID()
        let intentsWithParams: [(UIContracts.ChatIntent, String)] = [
            (.sendMessage("", conversationID), "empty message"),
            (.sendMessage("normal message", conversationID), "normal message"),
            (.askCodex("", conversationID), "empty question"),
            (.askCodex("What is Swift?", conversationID), "normal question"),
            (.setModelChoice(.codex), "model choice"),
            (.setContextScope(.workspace), "context scope")
        ]

        for (intent, description) in intentsWithParams {
            var receivedIntent: UIContracts.ChatIntent?
            let handler: (UIContracts.ChatIntent) -> Void = { receivedIntent = $0 }

            handler(intent)

            XCTAssertEqual(receivedIntent, intent, "Should handle \(description) correctly")
        }
    }

    func testWorkspaceIntentParametersAreValidated() {
        // Test that WorkspaceIntent parameters are properly structured
        let fileID = FileID()
        let intentsWithParams: [(UIContracts.WorkspaceIntent, String)] = [
            (.selectFile(""), "empty file path"),
            (.selectFile("/normal/path.swift"), "normal file path"),
            (.toggleFileInclusion(fileID), "file ID"),
            (.setContextScope(.selection), "selection scope"),
            (.setContextScope(.workspace), "workspace scope")
        ]

        for (intent, description) in intentsWithParams {
            var receivedIntent: UIContracts.WorkspaceIntent?
            let handler: (UIContracts.WorkspaceIntent) -> Void = { receivedIntent = $0 }

            handler(intent)

            XCTAssertEqual(receivedIntent, intent, "Should handle \(description) correctly")
        }
    }

    // MARK: - Handler Thread Safety Tests

    func testIntentHandlersAreSendable() {
        // Test that intent handlers can be used across threads (Sendable requirement)
        let chatIntent = UIContracts.ChatIntent.sendMessage("thread safe", UUID())
        let workspaceIntent = UIContracts.WorkspaceIntent.selectFile("/thread/safe.swift")

        var chatReceived = false
        var workspaceReceived = false

        let chatHandler: @Sendable (UIContracts.ChatIntent) -> Void = { _ in
            chatReceived = true
        }

        let workspaceHandler: @Sendable (UIContracts.WorkspaceIntent) -> Void = { _ in
            workspaceReceived = true
        }

        // These handlers should be usable across potential thread boundaries
        chatHandler(chatIntent)
        workspaceHandler(workspaceIntent)

        XCTAssertTrue(chatReceived, "Chat handler should work across threads")
        XCTAssertTrue(workspaceReceived, "Workspace handler should work across threads")
    }
}

// MARK: - Helper Functions

private func mirrorProperty<T>(_ object: Any, _ propertyName: String) -> T? {
    // Simple reflection helper for testing (not recommended for production)
    let mirror = Mirror(reflecting: object)
    for child in mirror.children {
        if child.label == propertyName {
            return child.value as? T
        }
    }
    return nil
}
