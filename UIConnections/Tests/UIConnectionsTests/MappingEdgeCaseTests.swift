import XCTest
import AppCoreEngine
@testable import UIConnections
import UIContracts

/// Tests for mapping edge cases.
/// Verifies that domain-to-UI mappings handle nil values, empty collections, boundaries, and extreme inputs correctly.
final class MappingEdgeCaseTests: XCTestCase {

    // MARK: - Nil Value Handling Tests

    func testConversationMappingWithNilValues() {
        // Test Conversation mapping with nil/empty values
        let conversation = AppCoreEngine.Conversation(
            id: UUID(),
            contextFilePaths: nil,
            contextDescriptorIDs: nil,
            messages: []
        )

        let uiConversation = DomainToUIMappers.toUIConversation(conversation)

        XCTAssertEqual(uiConversation.id, conversation.id)
        XCTAssertNil(uiConversation.contextDescriptorIDs)
        XCTAssertTrue(uiConversation.messages.isEmpty)
    }

    func testMessageMappingWithNilAttachments() {
        // Test Message mapping with nil attachments
        let message = AppCoreEngine.Message(
            id: UUID(),
            role: .user,
            text: "Hello",
            createdAt: Date(),
            attachments: nil
        )

        let uiMessage = DomainToUIMappers.toUIMessage(message)

        XCTAssertEqual(uiMessage.text, "Hello")
        XCTAssertEqual(uiMessage.role, .user)
        XCTAssertTrue(uiMessage.attachments.isEmpty)
    }

    func testWorkspaceViewStateMappingWithNilProjection() {
        // Test WorkspaceViewState mapping with nil projection
        let viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: "/project",
            selectedDescriptorID: nil,
            selectedPath: nil,
            projection: nil,
            contextInclusions: [:],
            watcherError: nil
        )

        XCTAssertEqual(viewState.rootPath, "/project")
        XCTAssertNil(viewState.selectedDescriptorID)
        XCTAssertNil(viewState.selectedPath)
        XCTAssertNil(viewState.projection)
        XCTAssertTrue(viewState.contextInclusions.isEmpty)
    }

    func testContextBuildResultMappingWithNilValues() {
        // Test ContextBuildResult mapping with nil values in collections
        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 0,
            totalTokens: 0,
            budget: .default,
            encodedSegments: []
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(contextResult)

        XCTAssertTrue(uiResult.attachments.isEmpty)
        XCTAssertTrue(uiResult.truncatedFiles.isEmpty)
        XCTAssertTrue(uiResult.excludedFiles.isEmpty)
        XCTAssertTrue(uiResult.encodedSegments.isEmpty)
        XCTAssertEqual(uiResult.totalBytes, 0)
        XCTAssertEqual(uiResult.totalTokens, 0)
    }

    // MARK: - Empty Collection Handling Tests

    func testConversationMappingWithEmptyCollections() {
        // Test Conversation mapping with empty collections
        let conversation = AppCoreEngine.Conversation(
            id: UUID(),
            contextFilePaths: [],
            contextDescriptorIDs: [],
            messages: []
        )

        let uiConversation = DomainToUIMappers.toUIConversation(conversation)

        XCTAssertTrue(uiConversation.contextFilePaths.isEmpty)
        XCTAssertTrue(uiConversation.contextDescriptorIDs?.isEmpty ?? false)
        XCTAssertTrue(uiConversation.messages.isEmpty)
    }

    func testWorkspaceSnapshotMappingWithEmptyCollections() {
        // Test WorkspaceSnapshot mapping with empty collections
        let snapshot = AppCoreEngine.WorkspaceSnapshot(
            rootPath: "/empty",
            selectedPath: nil,
            lastPersistedSelection: nil,
            selectedDescriptorID: nil,
            lastPersistedDescriptorID: nil,
            contextPreferences: .empty,
            descriptorPaths: [:],
            contextInclusions: [:],
            descriptors: []
        )

        let viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: snapshot.rootPath,
            selectedDescriptorID: snapshot.selectedDescriptorID,
            selectedPath: snapshot.selectedPath,
            projection: nil,
            contextInclusions: snapshot.contextInclusions,
            watcherError: nil
        )

        XCTAssertEqual(viewState.rootPath, "/empty")
        XCTAssertTrue(viewState.contextInclusions.isEmpty)
    }

    func testContextSnapshotMappingWithEmptySegments() {
        // Test ContextSnapshot mapping with empty segments
        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 0,
            totalTokens: 0,
            budget: .default,
            encodedSegments: []
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(contextResult)

        XCTAssertEqual(uiResult.encodedSegments.count, 0)
    }

    // MARK: - Boundary Value Tests

    func testMessageMappingWithExtremeLengths() {
        // Test Message mapping with extreme text lengths
        let shortMessage = AppCoreEngine.Message(
            id: UUID(),
            role: .user,
            text: "",
            createdAt: Date(),
            attachments: []
        )

        let longText = String(repeating: "a", count: 100000) // 100k characters
        let longMessage = AppCoreEngine.Message(
            id: UUID(),
            role: .assistant,
            text: longText,
            createdAt: Date(),
            attachments: []
        )

        let shortUIMessage = DomainToUIMappers.toUIMessage(shortMessage)
        let longUIMessage = DomainToUIMappers.toUIMessage(longMessage)

        XCTAssertEqual(shortUIMessage.text, "")
        XCTAssertEqual(longUIMessage.text.count, 100000)
        XCTAssertEqual(longUIMessage.text, longText)
    }

    func testFilePathMappingWithExtremeLengths() {
        // Test file path mapping with extreme lengths
        let shortPath = AppCoreEngine.WorkspaceSnapshot(
            rootPath: "/",
            selectedPath: nil,
            lastPersistedSelection: nil,
            selectedDescriptorID: nil,
            lastPersistedDescriptorID: nil,
            contextPreferences: .empty,
            descriptorPaths: [:],
            contextInclusions: [:],
            descriptors: []
        )

        let longPath = String(repeating: "a", count: 4096) // Very long path
        let longPathSnapshot = AppCoreEngine.WorkspaceSnapshot(
            rootPath: longPath,
            selectedPath: nil,
            lastPersistedSelection: nil,
            selectedDescriptorID: nil,
            lastPersistedDescriptorID: nil,
            contextPreferences: .empty,
            descriptorPaths: [:],
            contextInclusions: [:],
            descriptors: []
        )

        let shortViewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: shortPath.rootPath,
            selectedDescriptorID: nil,
            selectedPath: nil,
            projection: nil,
            contextInclusions: [:],
            watcherError: nil
        )

        let longViewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: longPathSnapshot.rootPath,
            selectedDescriptorID: nil,
            selectedPath: nil,
            projection: nil,
            contextInclusions: [:],
            watcherError: nil
        )

        XCTAssertEqual(shortViewState.rootPath, "/")
        XCTAssertEqual(longViewState.rootPath?.count, 4096)
    }

    func testNumericBoundaryMapping() {
        // Test mapping with extreme numeric values
        let maxIntResult = AppCoreEngine.ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: Int.max,
            totalTokens: Int.max,
            budget: AppCoreEngine.ContextBudget(maxTokens: Int.max, usedTokens: Int.max),
            encodedSegments: []
        )

        let zeroResult = AppCoreEngine.ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 0,
            totalTokens: 0,
            budget: AppCoreEngine.ContextBudget(maxTokens: 0, usedTokens: 0),
            encodedSegments: []
        )

        let maxUIResult = DomainToUIMappers.toUIContextBuildResult(maxIntResult)
        let zeroUIResult = DomainToUIMappers.toUIContextBuildResult(zeroResult)

        XCTAssertEqual(maxUIResult.totalBytes, Int.max)
        XCTAssertEqual(maxUIResult.totalTokens, Int.max)
        XCTAssertEqual(zeroUIResult.totalBytes, 0)
        XCTAssertEqual(zeroUIResult.totalTokens, 0)
    }

    // MARK: - Large Collection Handling Tests

    func testMappingWithLargeCollections() {
        // Test mapping with large numbers of items
        var largeMessages = [AppCoreEngine.Message]()
        for i in 0..<10000 {
            let message = AppCoreEngine.Message(
                id: UUID(),
                role: i % 2 == 0 ? .user : .assistant,
                text: "Message \(i)",
                createdAt: Date(),
                attachments: []
            )
            largeMessages.append(message)
        }

        let conversation = AppCoreEngine.Conversation(
            id: UUID(),
            contextFilePaths: [],
            contextDescriptorIDs: [],
            messages: largeMessages
        )

        let uiConversation = DomainToUIMappers.toUIConversation(conversation)

        XCTAssertEqual(uiConversation.messages.count, 10000)
        XCTAssertEqual(uiConversation.messages.first?.text, "Message 0")
        XCTAssertEqual(uiConversation.messages.last?.text, "Message 9999")
    }

    func testWorkspaceMappingWithManyInclusions() {
        // Test workspace mapping with many file inclusions
        var manyInclusions = [AppCoreEngine.FileID: AppCoreEngine.ContextInclusionState]()
        var fileIDs = [AppCoreEngine.FileID]()

        for i in 0..<1000 {
            let fileID = AppCoreEngine.FileID()
            fileIDs.append(fileID)
            manyInclusions[fileID] = i % 2 == 0 ? .included : .excluded
        }

        let viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: "/large",
            selectedDescriptorID: nil,
            selectedPath: nil,
            projection: nil,
            contextInclusions: manyInclusions,
            watcherError: nil
        )

        XCTAssertEqual(viewState.contextInclusions.count, 1000)
        // Verify some inclusions are preserved
        XCTAssertNotNil(viewState.contextInclusions[UIContracts.FileID(fileIDs[0].rawValue)])
    }

    func testContextMappingWithManySegments() {
        // Test context mapping with many segments
        var manySegments = [AppCoreEngine.ContextSegment]()
        for i in 0..<1000 {
            let segment = AppCoreEngine.ContextSegment(
                files: [AppCoreEngine.LoadedFile(
                    id: UUID(),
                    url: URL(fileURLWithPath: "/file\(i).swift"),
                    fileTypeIdentifier: "swift",
                    byteCount: 100
                )],
                totalTokens: 15,
                totalBytes: 100
            )
            manySegments.append(segment)
        }

        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 100000,
            totalTokens: 15000,
            budget: .default,
            encodedSegments: manySegments
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(contextResult)

        XCTAssertEqual(uiResult.encodedSegments.count, 1000)
        XCTAssertEqual(uiResult.totalBytes, 100000)
        XCTAssertEqual(uiResult.totalTokens, 15000)
    }

    // MARK: - Special Character and Unicode Tests

    func testMappingWithUnicodeContent() {
        // Test mapping with Unicode and special characters
        let unicodeMessage = AppCoreEngine.Message(
            id: UUID(),
            role: .user,
            text: "Hello 世界 🌍 with émojis and spëcial chärs 🚀",
            createdAt: Date(),
            attachments: []
        )

        let uiMessage = DomainToUIMappers.toUIMessage(unicodeMessage)

        XCTAssertEqual(uiMessage.text, "Hello 世界 🌍 with émojis and spëcial chärs 🚀")
    }

    func testMappingWithSpecialFilePaths() {
        // Test mapping with special characters in file paths
        let specialPaths = [
            "/file with spaces.swift",
            "/file-with-dashes.swift",
            "/file_with_underscores.swift",
            "/123numeric.swift",
            "/file(with)parens.swift",
            "/file[with]brackets.swift",
            "/file+plus.swift",
            "/file%percent.swift"
        ]

        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: specialPaths.map { path in
                AppCoreEngine.LoadedFile(
                    id: UUID(),
                    url: URL(fileURLWithPath: path),
                    fileTypeIdentifier: "swift",
                    byteCount: 100
                )
            },
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 800,
            totalTokens: 120,
            budget: .default,
            encodedSegments: []
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(contextResult)

        XCTAssertEqual(uiResult.attachments.count, 8)
        XCTAssertEqual(uiResult.totalBytes, 800)
        // Verify paths are preserved correctly
        XCTAssertTrue(uiResult.attachments.contains { $0.path == "/file with spaces.swift" })
        XCTAssertTrue(uiResult.attachments.contains { $0.path == "/file%percent.swift" })
    }

    // MARK: - Recursive Structure Edge Cases

    func testWorkspaceTreeMappingWithDeepNesting() {
        // Test workspace tree mapping with deep nesting
        func createNestedTree(depth: Int, name: String = "root") -> AppCoreEngine.WorkspaceTreeProjection {
            if depth == 0 {
                return AppCoreEngine.WorkspaceTreeProjection(
                    id: AppCoreEngine.FileID(),
                    name: "\(name).swift",
                    path: "/\(name).swift",
                    isDirectory: false,
                    children: []
                )
            }

            return AppCoreEngine.WorkspaceTreeProjection(
                id: AppCoreEngine.FileID(),
                name: name,
                path: "/\(name)",
                isDirectory: true,
                children: [createNestedTree(depth: depth - 1, name: "\(name)/child")]
            )
        }

        let deepTree = createNestedTree(depth: 10)
        let uiTree = DomainToUIMappers.toUIWorkspaceTree(deepTree)

        XCTAssertTrue(uiTree.isDirectory)
        XCTAssertEqual(uiTree.name, "root")
        // Verify deep nesting is preserved
        var current = uiTree
        for _ in 0..<9 {
            XCTAssertTrue(current.children.first?.isDirectory ?? false)
            current = current.children.first!
        }
        XCTAssertFalse(current.children.first?.isDirectory ?? true)
        XCTAssertEqual(current.children.first?.name, "root/child/child/child/child/child/child/child/child/child.swift")
    }

    func testEmptyNestedStructureMapping() {
        // Test mapping of empty nested structures
        let emptyDir = AppCoreEngine.WorkspaceTreeProjection(
            id: AppCoreEngine.FileID(),
            name: "empty",
            path: "/empty",
            isDirectory: true,
            children: []
        )

        let uiTree = DomainToUIMappers.toUIWorkspaceTree(emptyDir)

        XCTAssertTrue(uiTree.isDirectory)
        XCTAssertEqual(uiTree.name, "empty")
        XCTAssertTrue(uiTree.children.isEmpty)
    }

    // MARK: - Concurrent Modification Edge Cases

    func testMappingImmutability() {
        // Test that mappings don't mutate input data
        let originalMessage = AppCoreEngine.Message(
            id: UUID(),
            role: .user,
            text: "Original text",
            createdAt: Date(),
            attachments: []
        )

        // Map multiple times
        let uiMessage1 = DomainToUIMappers.toUIMessage(originalMessage)
        let uiMessage2 = DomainToUIMappers.toUIMessage(originalMessage)

        // Verify original is unchanged and mappings are consistent
        XCTAssertEqual(originalMessage.text, "Original text")
        XCTAssertEqual(uiMessage1.text, uiMessage2.text)
        XCTAssertEqual(uiMessage1.id, uiMessage2.id)
    }
}

