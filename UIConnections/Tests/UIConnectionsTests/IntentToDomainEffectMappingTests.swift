import XCTest
import AppCoreEngine
@testable import UIConnections
import UIContracts

/// Tests for intent-to-domain-effect mapping.
/// Verifies that UIContracts intents correctly route to AppCoreEngine domain operations.
final class IntentToDomainEffectMappingTests: XCTestCase {

    // MARK: - Domain to UI Mappers Tests

    func testConversationToUIConversationMapping() {
        // Test that DomainToUIMappers.toUIConversation correctly maps Conversation to UIConversation
        let domainConversation = AppCoreEngine.Conversation(
            id: UUID(),
            contextFilePaths: ["/file1.swift", "/file2.swift"],
            contextDescriptorIDs: [AppCoreEngine.FileID(), AppCoreEngine.FileID()],
            messages: []
        )

        let uiConversation = DomainToUIMappers.toUIConversation(domainConversation)

        XCTAssertEqual(uiConversation.id, domainConversation.id)
        XCTAssertEqual(uiConversation.contextFilePaths, ["/file1.swift", "/file2.swift"])
        XCTAssertEqual(uiConversation.contextDescriptorIDs?.count, 2)
        XCTAssertEqual(uiConversation.messages.count, 0)
    }

    func testMessageToUIMessageMapping() {
        // Test that DomainToUIMappers.toUIMessage correctly maps Message to UIMessage
        let domainMessage = AppCoreEngine.Message(
            id: UUID(),
            role: .assistant,
            text: "Hello from assistant",
            createdAt: Date(),
            attachments: []
        )

        let uiMessage = DomainToUIMappers.toUIMessage(domainMessage)

        XCTAssertEqual(uiMessage.id, domainMessage.id)
        XCTAssertEqual(uiMessage.role, .assistant)
        XCTAssertEqual(uiMessage.text, "Hello from assistant")
        XCTAssertEqual(uiMessage.createdAt, domainMessage.createdAt)
        XCTAssertEqual(uiMessage.attachments.count, 0)
    }

    func testWorkspaceTreeToUIWorkspaceTreeMapping() {
        // Test that DomainToUIMappers.toUIWorkspaceTree correctly maps WorkspaceTreeProjection to UIWorkspaceTree
        let childProjection = AppCoreEngine.WorkspaceTreeProjection(
            id: AppCoreEngine.FileID(),
            name: "child.swift",
            path: "/child.swift",
            isDirectory: false,
            children: []
        )

        let parentProjection = AppCoreEngine.WorkspaceTreeProjection(
            id: AppCoreEngine.FileID(),
            name: "src",
            path: "/src",
            isDirectory: true,
            children: [childProjection]
        )

        let uiTree = DomainToUIMappers.toUIWorkspaceTree(parentProjection)

        XCTAssertEqual(uiTree.name, "src")
        XCTAssertEqual(uiTree.path, "/src")
        XCTAssertTrue(uiTree.isDirectory)
        XCTAssertEqual(uiTree.children.count, 1)
        XCTAssertEqual(uiTree.children.first?.name, "child.swift")
    }

    func testContextBuildResultToUIContextBuildResultMapping() {
        // Test that DomainToUIMappers.toUIContextBuildResult correctly maps ContextBuildResult to UIContextBuildResult
        let loadedFile = AppCoreEngine.LoadedFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/test.swift"),
            fileTypeIdentifier: "swift",
            byteCount: 1000
        )

        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [loadedFile],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 1000,
            totalTokens: 150,
            budget: .default,
            encodedSegments: []
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(contextResult)

        XCTAssertEqual(uiResult.attachments.count, 1)
        XCTAssertEqual(uiResult.totalBytes, 1000)
        XCTAssertEqual(uiResult.totalTokens, 150)
        XCTAssertEqual(uiResult.truncatedFiles.count, 0)
        XCTAssertEqual(uiResult.excludedFiles.count, 0)
    }

    func testProjectTodosToUIProjectTodosMapping() {
        // Test that DomainToUIMappers.toUIProjectTodos correctly maps ProjectTodos to UIProjectTodos
        let domainTodo = AppCoreEngine.ProjectTodo(
            title: "Fix bug",
            filePath: "/test.swift",
            lineNumber: 42,
            isCompleted: false
        )

        let domainTodos = AppCoreEngine.ProjectTodos(
            generatedAt: Date(),
            missingHeaders: ["/missing1.swift"],
            missingFolderTelos: ["/missing_folder/"],
            filesWithIncompleteHeaders: ["/incomplete1.swift"],
            foldersWithIncompleteTelos: ["/incomplete_folder/"],
            allTodos: [domainTodo]
        )

        let uiTodos = DomainToUIMappers.toUIProjectTodos(domainTodos)

        XCTAssertEqual(uiTodos.missingHeaders, ["/missing1.swift"])
        XCTAssertEqual(uiTodos.missingFolderTelos, ["/missing_folder/"])
        XCTAssertEqual(uiTodos.filesWithIncompleteHeaders, ["/incomplete1.swift"])
        XCTAssertEqual(uiTodos.foldersWithIncompleteTelos, ["/incomplete_folder/"])
        XCTAssertEqual(uiTodos.allTodos.count, 1)
        XCTAssertEqual(uiTodos.allTodos.first?.title, "Fix bug")
    }

    // MARK: - Enum Mapping Tests

    func testMessageRoleMapping() {
        // Test that all MessageRole values map correctly to UIMessageRole
        XCTAssertEqual(DomainToUIMappers.toUIMessageRole(.user), .user)
        XCTAssertEqual(DomainToUIMappers.toUIMessageRole(.assistant), .assistant)
        XCTAssertEqual(DomainToUIMappers.toUIMessageRole(.system), .system)
    }

    func testContextInclusionStateMapping() {
        // Test that all ContextInclusionState values map correctly to UIContextInclusionState
        XCTAssertEqual(DomainToUIMappers.toUIContextInclusionState(.included), .included)
        XCTAssertEqual(DomainToUIMappers.toUIContextInclusionState(.excluded), .excluded)
        XCTAssertEqual(DomainToUIMappers.toUIContextInclusionState(.neutral), .neutral)
    }

    func testAttachmentMapping() {
        // Test that Attachment values map correctly to UIAttachment
        let fileAttachment = AppCoreEngine.Attachment.file(path: "/test.swift")
        let codeAttachment = AppCoreEngine.Attachment.code(language: "swift", content: "let x = 1")

        let uiFileAttachment = DomainToUIMappers.toUIAttachment(fileAttachment)
        let uiCodeAttachment = DomainToUIMappers.toUIAttachment(codeAttachment)

        if case .file(let path) = uiFileAttachment {
            XCTAssertEqual(path, "/test.swift")
        } else {
            XCTFail("Expected file attachment")
        }

        if case .code(let language, let content) = uiCodeAttachment {
            XCTAssertEqual(language, "swift")
            XCTAssertEqual(content, "let x = 1")
        } else {
            XCTFail("Expected code attachment")
        }
    }

    // MARK: - Complex Mapping Tests

    func testCompleteConversationMapping() {
        // Test mapping of a complete conversation with messages and attachments
        let attachment = AppCoreEngine.Attachment.code(language: "swift", content: "print(\"hello\")")

        let message = AppCoreEngine.Message(
            id: UUID(),
            role: .user,
            text: "Here's some code:",
            createdAt: Date(),
            attachments: [attachment]
        )

        let conversation = AppCoreEngine.Conversation(
            id: UUID(),
            contextFilePaths: ["/main.swift"],
            contextDescriptorIDs: [AppCoreEngine.FileID()],
            messages: [message]
        )

        let uiConversation = DomainToUIMappers.toUIConversation(conversation)

        XCTAssertEqual(uiConversation.messages.count, 1)
        XCTAssertEqual(uiConversation.messages.first?.text, "Here's some code:")
        XCTAssertEqual(uiConversation.messages.first?.role, .user)
        XCTAssertEqual(uiConversation.messages.first?.attachments.count, 1)
    }

    func testContextSnapshotMapping() {
        // Test mapping of complex context snapshot data
        let fileDescriptor = AppCoreEngine.ContextFileDescriptor(
            fileID: AppCoreEngine.FileID(),
            canonicalPath: "/test.swift",
            name: "test.swift",
            size: 500,
            tokens: 75,
            language: "swift"
        )

        let segment = AppCoreEngine.ContextSegment(
            files: [AppCoreEngine.LoadedFile(
                id: UUID(),
                url: URL(fileURLWithPath: "/test.swift"),
                fileTypeIdentifier: "swift",
                byteCount: 500
            )],
            totalTokens: 75,
            totalBytes: 500
        )

        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [AppCoreEngine.LoadedFile(
                id: UUID(),
                url: URL(fileURLWithPath: "/test.swift"),
                fileTypeIdentifier: "swift",
                byteCount: 500
            )],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 500,
            totalTokens: 75,
            budget: .default,
            encodedSegments: [segment]
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(contextResult)

        XCTAssertEqual(uiResult.attachments.count, 1)
        XCTAssertEqual(uiResult.encodedSegments.count, 1)
        XCTAssertEqual(uiResult.totalTokens, 75)
        XCTAssertEqual(uiResult.totalBytes, 500)
    }
}
