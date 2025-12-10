import XCTest
@testable import AppAdapters
import AppCoreEngine

final class FileStoreConversationPersistenceTests: XCTestCase {

    func testSaveAndLoadConversationRoundTrip() throws {
        let temp = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let persistence = FileStoreConversationPersistence(baseURL: temp)
        let convo = Conversation(
            id: UUID(),
            title: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 1),
            messages: [Message(role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 0))],
            contextFilePaths: [temp.appendingPathComponent("file.swift").path],
            contextDescriptorIDs: [FileID()]
        )

        try persistence.saveConversation(convo)
        let loaded = try persistence.loadAllConversations()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, convo.id)
        XCTAssertEqual(loaded.first?.messages.first?.text, "hi")

        // Index file should exist after save
        let indexURL = temp
            .appendingPathComponent("Conversations", isDirectory: true)
            .appendingPathComponent("index.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexURL.path))
    }

    func testDeleteRemovesFromIndex() throws {
        let temp = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let persistence = FileStoreConversationPersistence(baseURL: temp)
        let convo = Conversation(title: "DeleteMe")
        try persistence.saveConversation(convo)
        try persistence.deleteConversation(convo)

        let loaded = try persistence.loadAllConversations()
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - Helpers
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}


