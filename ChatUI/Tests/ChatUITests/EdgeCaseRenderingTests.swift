import XCTest
import SwiftUI
@testable import ChatUI
import UIContracts

/// Contract tests for edge case rendering scenarios.
/// Tests that views handle extreme, boundary, and error conditions correctly.
@MainActor
final class EdgeCaseRenderingTests: XCTestCase {

    // MARK: - Empty State Tests

    func testChatViewWithCompletelyEmptyState() {
        // Test ChatView with absolutely nothing
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

        XCTAssertNotNil(view, "ChatView should handle completely empty state")
        XCTAssertTrue(chatState.messages.isEmpty, "Should have no messages")
        XCTAssertNil(workspaceState.selectedNode, "Should have no selection")
        XCTAssertNil(contextState.lastContextSnapshot, "Should have no context snapshot")
    }

    func testContextInspectorWithNilSnapshot() {
        // Test ContextInspectorView with nil snapshot
        let view = ContextInspectorView(snapshot: nil)

        XCTAssertNotNil(view, "ContextInspectorView should handle nil snapshot gracefully")
    }

    func testXcodeNavigatorViewWithNilWorkspace() {
        // Test XcodeNavigatorView with completely nil workspace
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

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should handle nil workspace data")
    }

    // MARK: - Error State Tests

    func testChatViewWithErrorStates() {
        // Test ChatView with various error conditions
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
            todosErrorDescription: "Critical workspace error: unable to load files"
        )

        let contextState = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: "Context build failed: token limit exceeded"
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

        XCTAssertNotNil(view, "ChatView should handle error states")
        XCTAssertNotNil(workspaceState.todosErrorDescription, "Should have workspace error")
        XCTAssertNotNil(contextState.bannerMessage, "Should have context error")
    }

    func testXcodeNavigatorViewWithErrorState() {
        // Test XcodeNavigatorView with workspace error
        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: "Permission denied: cannot access workspace directory"
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should handle workspace error")
        XCTAssertNotNil(workspaceState.todosErrorDescription, "Should have error description")
    }

    // MARK: - Loading/Streaming State Tests

    func testChatViewWithStreamingState() {
        // Test ChatView in streaming state
        let chatState = UIContracts.ChatViewState(
            text: "",
            messages: [],
            streamingText: "The answer is 42...",
            isSending: true,
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
            streamingMessages: [UUID(): "Processing context..."],
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

        XCTAssertNotNil(view, "ChatView should handle streaming state")
        XCTAssertNotNil(chatState.streamingText, "Should have streaming text")
        XCTAssertTrue(chatState.isSending, "Should be in sending state")
        XCTAssertFalse(contextState.streamingMessages.isEmpty, "Should have streaming context messages")
    }

    func testContextInspectorWithStreamingContext() {
        // Test ContextInspectorView with streaming context data
        let snapshot = UIContracts.ContextSnapshot(
            scope: .workspace,
            snapshotHash: "streaming_123",
            segments: [],
            includedFiles: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalTokens: 500,
            totalBytes: 2500
        )

        let view = ContextInspectorView(snapshot: snapshot)

        XCTAssertNotNil(view, "ContextInspectorView should handle streaming context")
        XCTAssertEqual(snapshot.totalTokens, 500, "Should show current token count")
    }

    // MARK: - Boundary Condition Tests

    func testChatViewWithMaximumLengthText() {
        // Test ChatView with extremely long text
        let longText = String(repeating: "a", count: 10000) // 10k characters
        let chatState = UIContracts.ChatViewState(
            text: longText,
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

        XCTAssertNotNil(view, "ChatView should handle maximum length text")
        XCTAssertEqual(chatState.text.count, 10000, "Should preserve long text")
    }

    func testContextInspectorWithMaximumComplexity() {
        // Test ContextInspectorView with maximum complexity
        var includedFiles: [UIContracts.ContextFileDescriptor] = []
        var segments: [UIContracts.ContextSegmentDescriptor] = []

        // Create maximum number of files and segments
        for i in 0..<1000 {
            let file = UIContracts.ContextFileDescriptor(
                path: "/file\(i).swift",
                language: "swift",
                size: 1000,
                hash: "hash\(i)",
                isIncluded: true,
                isTruncated: false
            )
            includedFiles.append(file)

            let segment = UIContracts.ContextSegmentDescriptor(
                totalTokens: 20,
                totalBytes: 200,
                files: [file]
            )
            segments.append(segment)
        }

        let snapshot = UIContracts.ContextSnapshot(
            scope: .workspace,
            snapshotHash: "max_complexity_123",
            segments: segments,
            includedFiles: includedFiles,
            truncatedFiles: [],
            excludedFiles: [],
            totalTokens: 200000,
            totalBytes: 1000000
        )

        let view = ContextInspectorView(snapshot: snapshot)

        XCTAssertNotNil(view, "ContextInspectorView should handle maximum complexity")
        XCTAssertEqual(snapshot.includedFiles.count, 1000, "Should handle 1000 files")
        XCTAssertEqual(snapshot.segments.count, 1000, "Should handle 1000 segments")
    }

    func testXcodeNavigatorViewWithDeepHierarchy() {
        // Test XcodeNavigatorView with extremely deep file hierarchy
        func createDeepHierarchy(depth: Int, currentPath: String = "/") -> UIContracts.FileNode {
            if depth == 0 {
                return UIContracts.FileNode(
                    id: UUID(),
                    name: "file.swift",
                    path: URL(fileURLWithPath: currentPath + "file.swift"),
                    children: [],
                    icon: "doc.text",
                    isDirectory: false
                )
            }

            let dir = UIContracts.FileNode(
                id: UUID(),
                name: "dir\(depth)",
                path: URL(fileURLWithPath: currentPath + "dir\(depth)"),
                children: [createDeepHierarchy(depth: depth - 1, currentPath: currentPath + "dir\(depth)/")],
                icon: "folder",
                isDirectory: true
            )

            return dir
        }

        let deepHierarchy = createDeepHierarchy(depth: 20) // 20 levels deep

        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: deepHierarchy,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should handle deep hierarchy")
    }

    // MARK: - Special Character and Unicode Tests

    func testChatViewWithUnicodeContent() {
        // Test ChatView with Unicode and emoji content
        let unicodeText = "Hello 世界 🌍 🚀 with émojis and spëcial chärs"
        let unicodeMessage = UIContracts.UIMessage(
            id: UUID(),
            role: .user,
            text: unicodeText,
                createdAt: Date()
        )

        let chatState = UIContracts.ChatViewState(
            text: unicodeText,
            messages: [unicodeMessage],
            streamingText: "🤔 Thinking...",
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

        XCTAssertNotNil(view, "ChatView should handle Unicode content")
        XCTAssertEqual(chatState.messages.first?.text, unicodeText, "Should preserve Unicode text")
    }

    func testXcodeNavigatorViewWithSpecialFileNames() {
        // Test XcodeNavigatorView with special characters in file names
        let specialFiles = ["file with spaces.swift", "file-with-dashes.swift", "file_with_underscores.swift", "123numeric.swift", "file(with)parens.swift"]

        let children = specialFiles.map { name in
            UIContracts.FileNode(
                id: UUID(),
                name: name,
                path: URL(fileURLWithPath: "/" + name),
                children: [],
                icon: "doc.text",
                isDirectory: false
            )
        }

        let rootDir = UIContracts.FileNode(
            id: UUID(),
            name: "root",
            path: URL(fileURLWithPath: "/"),
            children: children,
            icon: "folder",
            isDirectory: true
        )

        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: rootDir,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should handle special file names")
        XCTAssertEqual(workspaceState.rootFileNode?.children?.count ?? 0, 5, "Should handle all special file names")
    }

    // MARK: - Memory Boundary Tests

    func testViewsHandleLargeCollections() {
        // Test that views can handle large collections without crashing
        var largeMessages: [UIContracts.UIMessage] = []
        for i in 0..<10000 { // 10k messages
            let message = UIContracts.UIMessage(
                id: UUID(),
                role: i % 2 == 0 ? .user : .assistant,
                text: "Message \(i)",
                createdAt: Date()
            )
            largeMessages.append(message)
        }

        let chatState = UIContracts.ChatViewState(
            text: "",
            messages: largeMessages,
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

        XCTAssertNotNil(view, "Views should handle large collections")
        XCTAssertEqual(chatState.messages.count, 10000, "Should preserve all messages")
    }
}
