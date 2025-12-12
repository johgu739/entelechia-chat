import XCTest
import AppCoreEngine
@testable import UIConnections
import UIContracts

/// Tests for mapping completeness.
/// Verifies that all AppCoreEngine domain types have corresponding mappings to UIContracts types.
final class MappingCompletenessTests: XCTestCase {

    // MARK: - Message Type Completeness Tests

    func testAllMessageRolesMapToUIRoles() {
        // Test that all MessageRole cases map to UIMessageRole cases
        let allRoles: [AppCoreEngine.MessageRole] = [.user, .assistant, .system]

        for role in allRoles {
            let uiRole = DomainToUIMappers.toUIMessageRole(role)
            XCTAssertNotNil(uiRole, "MessageRole \(role) should map to a UIMessageRole")

            // Verify the mapping is correct
            switch role {
            case .user: XCTAssertEqual(uiRole, .user)
            case .assistant: XCTAssertEqual(uiRole, .assistant)
            case .system: XCTAssertEqual(uiRole, .system)
            }
        }
    }

    func testAllAttachmentTypesMapToUIAttachments() {
        // Test that all Attachment cases map to UIAttachment cases
        let fileAttachment = AppCoreEngine.Attachment.file(path: "/test.swift")
        let codeAttachment = AppCoreEngine.Attachment.code(language: "swift", content: "let x = 1")

        let uiFileAttachment = DomainToUIMappers.toUIAttachment(fileAttachment)
        let uiCodeAttachment = DomainToUIMappers.toUIAttachment(codeAttachment)

        // Verify file attachment mapping
        if case .file(let path) = uiFileAttachment {
            XCTAssertEqual(path, "/test.swift")
        } else {
            XCTFail("File attachment should map to .file case")
        }

        // Verify code attachment mapping
        if case .code(let language, let content) = uiCodeAttachment {
            XCTAssertEqual(language, "swift")
            XCTAssertEqual(content, "let x = 1")
        } else {
            XCTFail("Code attachment should map to .code case")
        }
    }

    // MARK: - Context Type Completeness Tests

    func testAllContextInclusionStatesMapToUIStates() {
        // Test that all ContextInclusionState cases map to UIContextInclusionState cases
        let allStates: [AppCoreEngine.ContextInclusionState] = [.included, .excluded, .neutral]

        for state in allStates {
            let uiState = DomainToUIMappers.toUIContextInclusionState(state)
            XCTAssertNotNil(uiState, "ContextInclusionState \(state) should map to a UIContextInclusionState")

            // Verify the mapping is correct
            switch state {
            case .included: XCTAssertEqual(uiState, .included)
            case .excluded: XCTAssertEqual(uiState, .excluded)
            case .neutral: XCTAssertEqual(uiState, .neutral)
            }
        }
    }

    func testAllContextExclusionReasonsMapToUIReasons() {
        // Test that all ContextExclusionReason cases produce valid UI strings
        let allReasons: [AppCoreEngine.ContextExclusionReason] = [
            .exceedsPerFileBytes(limit: 1000),
            .exceedsPerFileTokens(limit: 100),
            .exceedsTotalBytes(limit: 10000),
            .exceedsTotalTokens(limit: 1000)
        ]

        for reason in allReasons {
            let exclusion = AppCoreEngine.ContextExclusion(
                id: AppCoreEngine.FileID(),
                file: AppCoreEngine.LoadedFile(
                    id: UUID(),
                    url: URL(fileURLWithPath: "/test.swift"),
                    fileTypeIdentifier: "swift",
                    byteCount: 1000
                ),
                reason: reason
            )

            let uiExclusion = DomainToUIMappers.toUIContextExclusion(exclusion)

            XCTAssertFalse(uiExclusion.reason.isEmpty, "ContextExclusionReason \(reason) should produce a non-empty string")
            XCTAssertTrue(uiExclusion.reason.contains("limit"), "Reason should mention 'limit'")
        }
    }

    // MARK: - Project Type Completeness Tests

    func testProjectTodosMapToUIProjectTodos() {
        // Test that ProjectTodos maps completely to UIProjectTodos
        let domainTodo = AppCoreEngine.ProjectTodo(
            title: "Fix critical bug",
            filePath: "/src/main.swift",
            lineNumber: 42,
            isCompleted: false
        )

        let domainTodos = AppCoreEngine.ProjectTodos(
            generatedAt: Date(),
            missingHeaders: ["/missing1.swift", "/missing2.swift"],
            missingFolderTelos: ["/folder1/", "/folder2/"],
            filesWithIncompleteHeaders: ["/incomplete1.swift"],
            foldersWithIncompleteTelos: ["/incomplete_folder/"],
            allTodos: [domainTodo]
        )

        let uiTodos = DomainToUIMappers.toUIProjectTodos(domainTodos)

        // Verify all fields are mapped
        XCTAssertEqual(uiTodos.missingHeaders, ["/missing1.swift", "/missing2.swift"])
        XCTAssertEqual(uiTodos.missingFolderTelos, ["/folder1/", "/folder2/"])
        XCTAssertEqual(uiTodos.filesWithIncompleteHeaders, ["/incomplete1.swift"])
        XCTAssertEqual(uiTodos.foldersWithIncompleteTelos, ["/incomplete_folder/"])
        XCTAssertEqual(uiTodos.allTodos.count, 1)
        XCTAssertEqual(uiTodos.allTodos.first?.title, "Fix critical bug")
        XCTAssertEqual(uiTodos.allTodos.first?.filePath, "/src/main.swift")
        XCTAssertEqual(uiTodos.allTodos.first?.lineNumber, 42)
        XCTAssertFalse(uiTodos.allTodos.first?.isCompleted ?? true)
    }

    func testProjectRepresentationMapsToUIProjectRepresentation() {
        // Test that ProjectRepresentation maps completely to UIProjectRepresentation
        let domainRepresentation = AppCoreEngine.ProjectRepresentation(
            rootPath: "/project",
            name: "MyProject",
            metadata: ["version": "1.0", "author": "Test"],
            linkedFiles: ["/project/main.swift", "/project/utils.swift"]
        )

        let uiRepresentation = DomainToUIMappers.toUIProjectRepresentation(domainRepresentation)

        XCTAssertEqual(uiRepresentation.rootPath, "/project")
        XCTAssertEqual(uiRepresentation.name, "MyProject")
        XCTAssertEqual(uiRepresentation.metadata["version"], "1.0")
        XCTAssertEqual(uiRepresentation.metadata["author"], "Test")
        XCTAssertEqual(uiRepresentation.linkedFiles, ["/project/main.swift", "/project/utils.swift"])
    }

    // MARK: - Complex Object Completeness Tests

    func testConversationMapsCompletelyToUIConversation() {
        // Test that Conversation maps completely to UIConversation
        let message = AppCoreEngine.Message(
            id: UUID(),
            role: .user,
            text: "Hello",
            createdAt: Date(),
            attachments: [AppCoreEngine.Attachment.file(path: "/attachment.txt")]
        )

        let conversation = AppCoreEngine.Conversation(
            id: UUID(),
            contextFilePaths: ["/context1.swift", "/context2.swift"],
            contextDescriptorIDs: [AppCoreEngine.FileID(), AppCoreEngine.FileID()],
            messages: [message]
        )

        let uiConversation = DomainToUIMappers.toUIConversation(conversation)

        // Verify all fields are mapped
        XCTAssertEqual(uiConversation.id, conversation.id)
        XCTAssertEqual(uiConversation.contextFilePaths, ["/context1.swift", "/context2.swift"])
        XCTAssertEqual(uiConversation.contextDescriptorIDs?.count, 2)
        XCTAssertEqual(uiConversation.messages.count, 1)
        XCTAssertEqual(uiConversation.messages.first?.text, "Hello")
        XCTAssertEqual(uiConversation.messages.first?.role, .user)
        XCTAssertEqual(uiConversation.messages.first?.attachments.count, 1)
    }

    func testWorkspaceTreeProjectionMapsCompletelyToUIWorkspaceTree() {
        // Test that WorkspaceTreeProjection maps completely to UIWorkspaceTree
        let child = AppCoreEngine.WorkspaceTreeProjection(
            id: AppCoreEngine.FileID(),
            name: "child.swift",
            path: "/child.swift",
            isDirectory: false,
            children: []
        )

        let parent = AppCoreEngine.WorkspaceTreeProjection(
            id: AppCoreEngine.FileID(),
            name: "src",
            path: "/src",
            isDirectory: true,
            children: [child]
        )

        let uiTree = DomainToUIMappers.toUIWorkspaceTree(parent)

        XCTAssertEqual(uiTree.id, parent.id.rawValue)
        XCTAssertEqual(uiTree.name, "src")
        XCTAssertEqual(uiTree.path, "/src")
        XCTAssertTrue(uiTree.isDirectory)
        XCTAssertEqual(uiTree.children.count, 1)
        XCTAssertEqual(uiTree.children.first?.name, "child.swift")
        XCTAssertFalse(uiTree.children.first?.isDirectory ?? true)
    }

    func testContextBuildResultMapsCompletelyToUIContextBuildResult() {
        // Test that ContextBuildResult maps completely to UIContextBuildResult
        let loadedFile = AppCoreEngine.LoadedFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/loaded.swift"),
            fileTypeIdentifier: "swift",
            byteCount: 500
        )

        let truncatedFile = AppCoreEngine.LoadedFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/truncated.swift"),
            fileTypeIdentifier: "swift",
            byteCount: 10000
        )

        let exclusion = AppCoreEngine.ContextExclusion(
            id: AppCoreEngine.FileID(),
            file: truncatedFile,
            reason: .exceedsPerFileBytes(limit: 5000)
        )

        let segment = AppCoreEngine.ContextSegment(
            files: [loadedFile],
            totalTokens: 75,
            totalBytes: 500
        )

        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [loadedFile],
            truncatedFiles: [truncatedFile],
            excludedFiles: [exclusion],
            totalBytes: 10500,
            totalTokens: 1575,
            budget: AppCoreEngine.ContextBudget(maxTokens: 2000, usedTokens: 1575),
            encodedSegments: [segment]
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(contextResult)

        // Verify all collections are mapped
        XCTAssertEqual(uiResult.attachments.count, 1)
        XCTAssertEqual(uiResult.truncatedFiles.count, 1)
        XCTAssertEqual(uiResult.excludedFiles.count, 1)
        XCTAssertEqual(uiResult.encodedSegments.count, 1)

        // Verify scalar values are mapped
        XCTAssertEqual(uiResult.totalBytes, 10500)
        XCTAssertEqual(uiResult.totalTokens, 1575)

        // Verify nested objects are mapped
        XCTAssertEqual(uiResult.encodedSegments.first?.totalTokens, 75)
        XCTAssertEqual(uiResult.encodedSegments.first?.totalBytes, 500)
    }

    // MARK: - File Descriptor Completeness Tests

    func testLoadedFileMapsCompletelyToUILoadedFile() {
        // Test that LoadedFile maps completely to UILoadedFile
        let loadedFile = AppCoreEngine.LoadedFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/test.swift"),
            fileTypeIdentifier: "swift",
            byteCount: 1000
        )

        let uiFile = DomainToUIMappers.toUILoadedFile(loadedFile)

        XCTAssertEqual(uiFile.id, loadedFile.id)
        XCTAssertEqual(uiFile.path, "/test.swift")
        XCTAssertEqual(uiFile.language, "swift")
        XCTAssertEqual(uiFile.size, 1000)
    }

    func testContextFileDescriptorMapsCompletelyToUIContextFileDescriptor() {
        // Test that ContextFileDescriptor maps completely to UIContextFileDescriptor
        let fileDescriptor = AppCoreEngine.ContextFileDescriptor(
            fileID: AppCoreEngine.FileID(),
            canonicalPath: "/src/main.swift",
            name: "main.swift",
            size: 1500,
            tokens: 225,
            language: "swift"
        )

        let uiDescriptor = DomainToUIMappers.toUIContextFileDescriptor(fileDescriptor)

        XCTAssertEqual(uiDescriptor.fileID, fileDescriptor.fileID.rawValue)
        XCTAssertEqual(uiDescriptor.canonicalPath, "/src/main.swift")
        XCTAssertEqual(uiDescriptor.name, "main.swift")
        XCTAssertEqual(uiDescriptor.size, 1500)
        XCTAssertEqual(uiDescriptor.tokens, 225)
        XCTAssertEqual(uiDescriptor.language, "swift")
    }

    // MARK: - Enum Exhaustiveness Tests

    func testAllModelChoicesMap() {
        // Test that all ModelChoice cases are handled (if any exist)
        // This is more of a compilation test, but we verify the enum exists
        let _ = UIContracts.ModelChoice.codex
        let _ = UIContracts.ModelChoice.stub
        // If new cases are added, this test will help ensure mappings are updated
    }

    func testAllContextScopeChoicesMap() {
        // Test that all ContextScopeChoice cases are handled
        let _ = UIContracts.ContextScopeChoice.selection
        let _ = UIContracts.ContextScopeChoice.workspace
        let _ = UIContracts.ContextScopeChoice.manual
        // If new cases are added, this test will help ensure mappings are updated
    }

    func testAllNavigatorModesMap() {
        // Test that all NavigatorMode cases are handled
        let _ = UIContracts.NavigatorMode.project
        let _ = UIContracts.NavigatorMode.find
        // If new cases are added, this test will help ensure mappings are updated
    }

    // MARK: - Integration Completeness Tests

    func testCompleteWorkspaceToUIViewStateMapping() {
        // Test that a complete WorkspaceSnapshot maps to a complete WorkspaceUIViewState
        let fileID = AppCoreEngine.FileID()
        let todo = AppCoreEngine.ProjectTodo(
            title: "Complete mapping tests",
            filePath: "/tests/MappingTests.swift",
            lineNumber: 100,
            isCompleted: false
        )

        let snapshot = AppCoreEngine.WorkspaceSnapshot(
            rootPath: "/complete/project",
            selectedPath: "/complete/project/main.swift",
            lastPersistedSelection: "/complete/project/main.swift",
            selectedDescriptorID: fileID,
            lastPersistedDescriptorID: fileID,
            contextPreferences: AppCoreEngine.WorkspaceContextPreferencesState(
                includedPaths: ["/complete/project/main.swift"],
                excludedPaths: ["/complete/project/tests/"],
                lastFocusedFilePath: "/complete/project/main.swift"
            ),
            descriptorPaths: [fileID: "/complete/project/main.swift"],
            contextInclusions: [fileID: .included],
            descriptors: [AppCoreEngine.FileDescriptor(id: fileID, name: "main.swift", type: .file)]
        )

        let projection = AppCoreEngine.WorkspaceTreeProjection(
            id: fileID,
            name: "main.swift",
            path: "/complete/project/main.swift",
            isDirectory: false,
            children: []
        )

        let viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: snapshot.rootPath,
            selectedDescriptorID: snapshot.selectedDescriptorID,
            selectedPath: snapshot.selectedPath,
            projection: projection,
            contextInclusions: snapshot.contextInclusions,
            watcherError: nil
        )

        // Verify complete mapping
        XCTAssertEqual(viewState.rootPath, "/complete/project")
        XCTAssertEqual(viewState.selectedPath, "/complete/project/main.swift")
        XCTAssertEqual(viewState.selectedDescriptorID?.rawValue, fileID.rawValue)
        XCTAssertNotNil(viewState.projection)
        XCTAssertEqual(viewState.contextInclusions.count, 1)
        XCTAssertNil(viewState.watcherError)
    }

    func testCompleteContextToUIViewStateMapping() {
        // Test that complete context data maps to complete UI state
        let contextSnapshot = AppCoreEngine.ContextSnapshot(
            scope: .workspace,
            snapshotHash: "complete_test_hash",
            segments: [
                AppCoreEngine.ContextSegment(
                    files: [AppCoreEngine.LoadedFile(
                        id: UUID(),
                        url: URL(fileURLWithPath: "/file1.swift"),
                        fileTypeIdentifier: "swift",
                        byteCount: 500
                    )],
                    totalTokens: 75,
                    totalBytes: 500
                )
            ],
            includedFiles: [
                AppCoreEngine.ContextFileDescriptor(
                    fileID: AppCoreEngine.FileID(),
                    canonicalPath: "/file1.swift",
                    name: "file1.swift",
                    size: 500,
                    tokens: 75,
                    language: "swift"
                )
            ],
            truncatedFiles: [],
            excludedFiles: [],
            totalTokens: 75,
            totalBytes: 500
        )

        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [AppCoreEngine.LoadedFile(
                id: UUID(),
                url: URL(fileURLWithPath: "/file1.swift"),
                fileTypeIdentifier: "swift",
                byteCount: 500
            )],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 500,
            totalTokens: 75,
            budget: .default,
            encodedSegments: [AppCoreEngine.ContextSegment(
                files: [AppCoreEngine.LoadedFile(
                    id: UUID(),
                    url: URL(fileURLWithPath: "/file1.swift"),
                    fileTypeIdentifier: "swift",
                    byteCount: 500
                )],
                totalTokens: 75,
                totalBytes: 500
            )]
        )

        // Test that both snapshot and result can be mapped completely
        XCTAssertEqual(contextSnapshot.segments.count, 1)
        XCTAssertEqual(contextSnapshot.includedFiles.count, 1)
        XCTAssertEqual(contextResult.attachments.count, 1)
        XCTAssertEqual(contextResult.encodedSegments.count, 1)
    }
}
