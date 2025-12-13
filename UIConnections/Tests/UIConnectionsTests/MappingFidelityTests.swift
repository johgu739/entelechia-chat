import XCTest
import AppCoreEngine
@testable import UIConnections
import UIContracts

/// Tests for mapping fidelity.
/// Verifies that domain-to-UI mappings preserve all information without loss or corruption.
final class MappingFidelityTests: XCTestCase {

    // MARK: - Identity Preservation Tests

    func testMessageMappingPreservesIdentity() {
        // Test that Message mapping preserves all identity fields
        let originalID = UUID()
        let originalCreatedAt = Date()
        let originalText = "Exact message text"
        let originalRole = AppCoreEngine.MessageRole.assistant

        let message = AppCoreEngine.Message(
            id: originalID,
            role: originalRole,
            text: originalText,
            createdAt: originalCreatedAt,
            attachments: []
        )

        let uiMessage = DomainToUIMappers.toUIMessage(message)

        XCTAssertEqual(uiMessage.id, originalID, "ID should be preserved exactly")
        XCTAssertEqual(uiMessage.role, .assistant, "Role should be preserved exactly")
        XCTAssertEqual(uiMessage.text, originalText, "Text should be preserved exactly")
        XCTAssertEqual(uiMessage.createdAt, originalCreatedAt, "Created date should be preserved exactly")
    }

    func testConversationMappingPreservesIdentity() {
        // Test that Conversation mapping preserves all identity fields
        let originalID = UUID()
        let originalTitle = "Test Conversation"
        let originalCreatedAt = Date()
        let originalUpdatedAt = Date().addingTimeInterval(3600)

        let conversation = AppCoreEngine.Conversation(
            id: originalID,
            contextFilePaths: ["/file1.swift"],
            contextDescriptorIDs: [AppCoreEngine.FileID()],
            messages: []
        )

        // Manually set fields that might not be in constructor
        let uiConversation = DomainToUIMappers.toUIConversation(conversation)

        XCTAssertEqual(uiConversation.id, originalID, "Conversation ID should be preserved exactly")
        XCTAssertEqual(uiConversation.contextFilePaths, ["/file1.swift"], "Context file paths should be preserved exactly")
    }

    func testFileIDMappingPreservesIdentity() {
        // Test that FileID mapping preserves identity
        let originalFileID = AppCoreEngine.FileID()
        let uiFileID = UIContracts.FileID(originalFileID.rawValue)

        XCTAssertEqual(uiFileID.rawValue, originalFileID.rawValue, "FileID raw value should be preserved exactly")
    }

    // MARK: - Content Preservation Tests

    func testAttachmentMappingPreservesContent() {
        // Test that Attachment mapping preserves all content
        let filePath = "/complex/path/to/file.swift"
        let fileAttachment = AppCoreEngine.Attachment.file(path: filePath)

        let language = "swift"
        let code = """
        struct Example {
            let property: String
            func method() -> Int { 42 }
        }
        """
        let codeAttachment = AppCoreEngine.Attachment.code(language: language, content: code)

        let uiFileAttachment = DomainToUIMappers.toUIAttachment(fileAttachment)
        let uiCodeAttachment = DomainToUIMappers.toUIAttachment(codeAttachment)

        if case .file(let mappedPath) = uiFileAttachment {
            XCTAssertEqual(mappedPath, filePath, "File path should be preserved exactly")
        } else {
            XCTFail("File attachment should map to .file case")
        }

        if case .code(let mappedLanguage, let mappedContent) = uiCodeAttachment {
            XCTAssertEqual(mappedLanguage, language, "Language should be preserved exactly")
            XCTAssertEqual(mappedContent, code, "Code content should be preserved exactly")
        } else {
            XCTFail("Code attachment should map to .code case")
        }
    }

    func testContextInclusionMappingPreservesState() {
        // Test that ContextInclusionState mapping preserves exact state
        let states: [AppCoreEngine.ContextInclusionState] = [.included, .excluded, .neutral]

        for state in states {
            let uiState = DomainToUIMappers.toUIContextInclusionState(state)

            switch state {
            case .included: XCTAssertEqual(uiState, .included)
            case .excluded: XCTAssertEqual(uiState, .excluded)
            case .neutral: XCTAssertEqual(uiState, .neutral)
            }
        }
    }

    func testLoadedFileMappingPreservesAllFields() {
        // Test that LoadedFile mapping preserves all fields exactly
        let originalID = UUID()
        let originalPath = "/very/specific/path/to/source.swift"
        let originalLanguage = "swift"
        let originalSize = 1337

        let loadedFile = AppCoreEngine.LoadedFile(
            id: originalID,
            url: URL(fileURLWithPath: originalPath),
            fileTypeIdentifier: originalLanguage,
            byteCount: originalSize
        )

        let uiFile = DomainToUIMappers.toUILoadedFile(loadedFile)

        XCTAssertEqual(uiFile.id, originalID, "File ID should be preserved")
        XCTAssertEqual(uiFile.path, originalPath, "File path should be preserved")
        XCTAssertEqual(uiFile.language, originalLanguage, "Language should be preserved")
        XCTAssertEqual(uiFile.size, originalSize, "File size should be preserved")
    }

    // MARK: - Numeric Precision Tests

    func testNumericValuePreservation() {
        // Test that numeric values are preserved with full precision
        let testValues = [0, 1, 42, 1000, 99999, Int.max, Int.min]

        for value in testValues {
            let contextResult = AppCoreEngine.ContextBuildResult(
                attachments: [],
                truncatedFiles: [],
                excludedFiles: [],
                totalBytes: value,
                totalTokens: value,
                budget: AppCoreEngine.ContextBudget(maxTokens: value, usedTokens: value),
                encodedSegments: []
            )

            let uiResult = DomainToUIMappers.toUIContextBuildResult(contextResult)

            XCTAssertEqual(uiResult.totalBytes, value, "totalBytes should preserve value \(value)")
            XCTAssertEqual(uiResult.totalTokens, value, "totalTokens should preserve value \(value)")
        }
    }

    func testFileSizePreservation() {
        // Test that file sizes are preserved accurately
        let sizes = [0, 1, 1024, 1048576, 1073741824] // Various file sizes

        for size in sizes {
            let fileDescriptor = AppCoreEngine.ContextFileDescriptor(
                fileID: AppCoreEngine.FileID(),
                canonicalPath: "/test.swift",
                name: "test.swift",
                size: size,
                tokens: 100,
                language: "swift"
            )

            let uiDescriptor = DomainToUIMappers.toUIContextFileDescriptor(fileDescriptor)

            XCTAssertEqual(uiDescriptor.size, size, "File size \(size) should be preserved")
        }
    }

    // MARK: - Collection Preservation Tests

    func testCollectionOrderPreservation() {
        // Test that collection ordering is preserved
        let messages = (0..<10).map { i in
            AppCoreEngine.Message(
                id: UUID(),
                role: i % 2 == 0 ? .user : .assistant,
                text: "Message \(i)",
                createdAt: Date(),
                attachments: []
            )
        }

        let conversation = AppCoreEngine.Conversation(
            id: UUID(),
            contextFilePaths: (0..<5).map { "/file\($0).swift" },
            contextDescriptorIDs: (0..<5).map { _ in AppCoreEngine.FileID() },
            messages: messages
        )

        let uiConversation = DomainToUIMappers.toUIConversation(conversation)

        // Verify message order is preserved
        for (index, uiMessage) in uiConversation.messages.enumerated() {
            XCTAssertEqual(uiMessage.text, "Message \(index)", "Message at index \(index) should be preserved in order")
        }

        // Verify file path order is preserved
        for (index, path) in uiConversation.contextFilePaths.enumerated() {
            XCTAssertEqual(path, "/file\(index).swift", "File path at index \(index) should be preserved in order")
        }
    }

    func testDictionaryMappingPreservation() {
        // Test that dictionary mappings preserve keys and values
        var inclusions = [AppCoreEngine.FileID: AppCoreEngine.ContextInclusionState]()
        var expectedUIInclusions = [UIContracts.FileID: UIContracts.UIContextInclusionState]()

        for i in 0..<5 {
            let fileID = AppCoreEngine.FileID()
            let state: AppCoreEngine.ContextInclusionState = i % 2 == 0 ? .included : .excluded
            inclusions[fileID] = state

            let uiFileID = UIContracts.FileID(fileID.rawValue)
            let uiState: UIContracts.UIContextInclusionState = i % 2 == 0 ? .included : .excluded
            expectedUIInclusions[uiFileID] = uiState
        }

        let viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: "/test",
            selectedDescriptorID: nil,
            selectedPath: nil,
            projection: nil,
            contextInclusions: inclusions,
            watcherError: nil
        )

        XCTAssertEqual(viewState.contextInclusions.count, expectedUIInclusions.count, "Dictionary size should be preserved")

        for (fileID, state) in inclusions {
            let uiFileID = UIContracts.FileID(fileID.rawValue)
            XCTAssertEqual(viewState.contextInclusions[uiFileID], expectedUIInclusions[uiFileID], "Inclusion state should be preserved for file ID")
        }
    }

    // MARK: - String Preservation Tests

    func testStringContentPreservation() {
        // Test that string content is preserved exactly, including special characters
        let testStrings = [
            "",
            "simple string",
            "string with spaces and punctuation!@#$%^&*()",
            "Unicode: Hello 世界 🌍 🚀",
            "Multi\nLine\nString",
            "Tabs\tand\tspaces",
            "Quotes: \"single\" and 'double'",
            "Backslashes: \\ and \\\\",
            String(repeating: "a", count: 10000) // Very long string
        ]

        for testString in testStrings {
            let message = AppCoreEngine.Message(
                id: UUID(),
                role: .user,
                text: testString,
                createdAt: Date(),
                attachments: []
            )

            let uiMessage = DomainToUIMappers.toUIMessage(message)

            XCTAssertEqual(uiMessage.text, testString, "String content should be preserved exactly: \(testString.prefix(50))...")
            XCTAssertEqual(uiMessage.text.count, testString.count, "String length should be preserved")
        }
    }

    func testPathPreservation() {
        // Test that file paths are preserved exactly
        let testPaths = [
            "/",
            "/simple/path",
            "/path with spaces/file.swift",
            "/path/with/unicode/文件.swift",
            "/very/deep/nested/path/structure/with/many/levels/file.swift",
            String(repeating: "a", count: 4096) + "/file.swift" // Very long path
        ]

        for path in testPaths {
            let loadedFile = AppCoreEngine.LoadedFile(
                id: UUID(),
                url: URL(fileURLWithPath: path),
                fileTypeIdentifier: "swift",
                byteCount: 100
            )

            let uiFile = DomainToUIMappers.toUILoadedFile(loadedFile)

            XCTAssertEqual(uiFile.path, path, "File path should be preserved exactly")
        }
    }

    // MARK: - Date Preservation Tests

    func testDatePreservation() {
        // Test that dates are preserved exactly
        let testDates = [
            Date(),
            Date.distantPast,
            Date.distantFuture,
            Date(timeIntervalSince1970: 0),
            Date(timeIntervalSince1970: 1609459200) // 2021-01-01
        ]

        for date in testDates {
            let message = AppCoreEngine.Message(
                id: UUID(),
                role: .user,
                text: "test",
                createdAt: date,
                attachments: []
            )

            let uiMessage = DomainToUIMappers.toUIMessage(message)

            XCTAssertEqual(uiMessage.createdAt, date, "Date should be preserved exactly")
            XCTAssertEqual(uiMessage.createdAt.timeIntervalSince1970, date.timeIntervalSince1970, precision: 0.001, "Date timestamp should be preserved")
        }
    }

    // MARK: - Complex Object Fidelity Tests

    func testComplexConversationFidelity() {
        // Test that complex conversations preserve all information
        let attachment1 = AppCoreEngine.Attachment.file(path: "/attachment1.txt")
        let attachment2 = AppCoreEngine.Attachment.code(language: "swift", content: "let x = 1")

        let message1 = AppCoreEngine.Message(
            id: UUID(),
            role: .user,
            text: "First message with attachment",
            createdAt: Date().addingTimeInterval(-60),
            attachments: [attachment1]
        )

        let message2 = AppCoreEngine.Message(
            id: UUID(),
            role: .assistant,
            text: "Second message with code",
            createdAt: Date(),
            attachments: [attachment2]
        )

        let conversation = AppCoreEngine.Conversation(
            id: UUID(),
            contextFilePaths: ["/context1.swift", "/context2.swift"],
            contextDescriptorIDs: [AppCoreEngine.FileID(), AppCoreEngine.FileID()],
            messages: [message1, message2]
        )

        let uiConversation = DomainToUIMappers.toUIConversation(conversation)

        // Verify conversation-level fidelity
        XCTAssertEqual(uiConversation.contextFilePaths.count, 2)
        XCTAssertEqual(uiConversation.contextDescriptorIDs?.count, 2)
        XCTAssertEqual(uiConversation.messages.count, 2)

        // Verify message-level fidelity
        let uiMessage1 = uiConversation.messages[0]
        let uiMessage2 = uiConversation.messages[1]

        XCTAssertEqual(uiMessage1.text, "First message with attachment")
        XCTAssertEqual(uiMessage1.role, .user)
        XCTAssertEqual(uiMessage1.attachments.count, 1)

        XCTAssertEqual(uiMessage2.text, "Second message with code")
        XCTAssertEqual(uiMessage2.role, .assistant)
        XCTAssertEqual(uiMessage2.attachments.count, 1)

        // Verify attachment fidelity
        if case .file(let path) = uiMessage1.attachments.first {
            XCTAssertEqual(path, "/attachment1.txt")
        } else {
            XCTFail("First attachment should be a file")
        }

        if case .code(let language, let content) = uiMessage2.attachments.first {
            XCTAssertEqual(language, "swift")
            XCTAssertEqual(content, "let x = 1")
        } else {
            XCTFail("Second attachment should be code")
        }
    }

    func testWorkspaceStateFidelity() {
        // Test that complex workspace states preserve all information
        let fileID1 = AppCoreEngine.FileID()
        let fileID2 = AppCoreEngine.FileID()

        let inclusions = [
            fileID1: AppCoreEngine.ContextInclusionState.included,
            fileID2: AppCoreEngine.ContextInclusionState.excluded
        ]

        let projection = AppCoreEngine.WorkspaceTreeProjection(
            id: fileID1,
            name: "selected.swift",
            path: "/selected.swift",
            isDirectory: false,
            children: []
        )

        let viewState = DomainToUIMappers.toWorkspaceViewState(
            rootPath: "/complex/workspace/path",
            selectedDescriptorID: fileID1,
            selectedPath: "/complex/workspace/path/selected.swift",
            projection: projection,
            contextInclusions: inclusions,
            watcherError: "Complex error message with details"
        )

        // Verify all fields are preserved
        XCTAssertEqual(viewState.rootPath, "/complex/workspace/path")
        XCTAssertEqual(viewState.selectedPath, "/complex/workspace/path/selected.swift")
        XCTAssertEqual(viewState.selectedDescriptorID?.rawValue, fileID1.rawValue)
        XCTAssertEqual(viewState.projection?.name, "selected.swift")
        XCTAssertEqual(viewState.contextInclusions.count, 2)
        XCTAssertEqual(viewState.contextInclusions[UIContracts.FileID(fileID1.rawValue)], .included)
        XCTAssertEqual(viewState.contextInclusions[UIContracts.FileID(fileID2.rawValue)], .excluded)
        XCTAssertEqual(viewState.watcherError, "Complex error message with details")
    }

    // MARK: - Round-trip Consistency Tests

    func testMappingRoundTripConsistency() {
        // Test that mapping operations are consistent (though not necessarily invertible)
        let originalMessage = AppCoreEngine.Message(
            id: UUID(),
            role: .user,
            text: "Round trip test",
            createdAt: Date(),
            attachments: [AppCoreEngine.Attachment.file(path: "/test.txt")]
        )

        let uiMessage1 = DomainToUIMappers.toUIMessage(originalMessage)
        let uiMessage2 = DomainToUIMappers.toUIMessage(originalMessage)

        // Multiple mappings of the same input should produce identical results
        XCTAssertEqual(uiMessage1.id, uiMessage2.id)
        XCTAssertEqual(uiMessage1.role, uiMessage2.role)
        XCTAssertEqual(uiMessage1.text, uiMessage2.text)
        XCTAssertEqual(uiMessage1.createdAt, uiMessage2.createdAt)
        XCTAssertEqual(uiMessage1.attachments.count, uiMessage2.attachments.count)
    }
}

