import Foundation
import Engine
@preconcurrency import os.log

/// Disk-backed conversation persistence adapter wrapping existing FileStore logic.
public final class FileStoreConversationPersistence: ConversationPersistenceDriver, @unchecked Sendable {
    public typealias ConversationType = Conversation

    private let fileStore: FileStore
    private let logger = Logger(subsystem: "chat.entelechia.uiconnections", category: "FileStoreConversation")

    public init(baseURL: URL? = nil) {
        self.fileStore = FileStore(baseURL: baseURL)
    }

    public func loadAllConversations() throws -> [Conversation] {
        try fileStore.ensureDirectoryExists()

        let indexURL = fileStore.resolveIndexPath()
        let index: ConversationIndex? = try fileStore.load(ConversationIndex.self, from: indexURL)

        var loaded: [Conversation] = []

        if let index {
            for entry in index.conversations {
                let conversationURL = fileStore.resolveConversationsDirectory()
                    .appendingPathComponent("\(entry.id.uuidString).json")
                if let conversation = try fileStore.load(Conversation.self, from: conversationURL) {
                    loaded.append(conversation)
                } else {
                    logger.warning("Missing conversation file for id \(entry.id.uuidString, privacy: .public)")
                }
            }
        }

        // Import orphan files not in index
        let orphanFiles = try fileStore.listConversationFiles()
        for fileURL in orphanFiles {
            let filename = fileURL.deletingPathExtension().lastPathComponent
            guard UUID(uuidString: filename) != nil else { continue }
            if let conversation = try fileStore.load(Conversation.self, from: fileURL) {
                if !loaded.contains(where: { $0.id == conversation.id }) {
                    loaded.append(conversation)
                }
            }
        }

        // Sort
        return loaded.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func saveConversation(_ conversation: Conversation) throws {
        try fileStore.ensureDirectoryExists()
        let conversationURL = fileStore.resolveConversationsDirectory()
            .appendingPathComponent("\(conversation.id.uuidString).json")
        try fileStore.save(conversation, to: conversationURL)

        // Sync index
        try syncIndex(with: [conversation])
    }

    public func deleteConversation(_ conversation: Conversation) throws {
        let conversationURL = fileStore.resolveConversationsDirectory()
            .appendingPathComponent("\(conversation.id.uuidString).json")
        try fileStore.delete(at: conversationURL)
        try syncIndex(without: conversation.id)
    }

    private func syncIndex(with conversations: [Conversation]) throws {
        // For simplicity, rewrite full index using all on-disk conversations.
        let all = try loadAllConversations()
        let entries = all.map { entry in
            ConversationIndexEntry(
                id: entry.id,
                title: entry.title,
                updatedAt: entry.updatedAt,
                path: "\(entry.id.uuidString).json"
            )
        }
        let index = ConversationIndex(version: 1, conversations: entries)
        try fileStore.save(index, to: fileStore.resolveIndexPath())
    }

    private func syncIndex(without id: UUID) throws {
        let all = try loadAllConversations().filter { $0.id != id }
        let entries = all.map { entry in
            ConversationIndexEntry(
                id: entry.id,
                title: entry.title,
                updatedAt: entry.updatedAt,
                path: "\(entry.id.uuidString).json"
            )
        }
        let index = ConversationIndex(version: 1, conversations: entries)
        try fileStore.save(index, to: fileStore.resolveIndexPath())
    }
}

// MARK: - Internal FileStore wrapper (copied/trimmed for adapter use)

final class FileStore {
    private let logger = Logger(subsystem: "chat.entelechia.uiconnections", category: "FileStore")
    private let baseURL: URL

    init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else if let override = ProcessInfo.processInfo.environment["ENTELECHIA_APP_SUPPORT"] {
            self.baseURL = URL(fileURLWithPath: override, isDirectory: true)
                .appendingPathComponent("Entelechia", isDirectory: true)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseURL = appSupport.appendingPathComponent("Entelechia", isDirectory: true)
        }
    }

    func resolveDatabasePath() -> URL {
        baseURL
    }

    func resolveConversationsDirectory() -> URL {
        resolveDatabasePath().appendingPathComponent("Conversations", isDirectory: true)
    }

    func resolveIndexPath() -> URL {
        resolveConversationsDirectory().appendingPathComponent("index.json", isDirectory: false)
    }

    func ensureDirectoryExists() throws {
        let conversationsDir = resolveConversationsDirectory()
        try FileManager.default.createDirectory(at: conversationsDir, withIntermediateDirectories: true)
        logger.debug("Ensured conversations directory exists at \(conversationsDir.path, privacy: .private)")
    }

    func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, to url: URL) throws {
        let parentDir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
        logger.debug("Saved file at \(url.path, privacy: .private)")
    }

    func delete(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
            logger.debug("Deleted file at \(url.path, privacy: .private)")
        }
    }

    func listConversationFiles() throws -> [URL] {
        let conversationsDir = resolveConversationsDirectory()
        guard FileManager.default.fileExists(atPath: conversationsDir.path) else {
            return []
        }
        return try FileManager.default.contentsOfDirectory(
            at: conversationsDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }
    }
}

