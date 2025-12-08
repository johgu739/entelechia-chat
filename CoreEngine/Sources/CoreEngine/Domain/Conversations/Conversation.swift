import Foundation

/// Conversation aggregate (pure, portable).
public struct Conversation: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var updatedAt: Date
    public var messages: [Message]
    public var contextFilePaths: [String]
    public var contextDescriptorIDs: [FileID]?

    public enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case updatedAt
        case messages
        case contextFilePaths
        case contextDescriptorIDs
    }

    public init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [Message] = [],
        contextFilePaths: [String] = [],
        contextDescriptorIDs: [FileID]? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
        self.contextFilePaths = contextFilePaths
        self.contextDescriptorIDs = contextDescriptorIDs
    }

    /// Compute summary title from first user message.
    public var summaryTitle: String {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let words = firstUserMessage.text
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            let preview = words.prefix(8).joined(separator: " ")
            return preview.isEmpty ? "New Conversation" : preview
        }
        return "New Conversation"
    }

    /// Convenience property for context URL (first path).
    public var contextURL: URL? {
        contextFilePaths.first.flatMap { URL(fileURLWithPath: $0) }
    }
}

/// Index entry for conversation metadata.
public struct ConversationIndexEntry: Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let updatedAt: Date
    public let path: String

    public init(id: UUID, title: String, updatedAt: Date, path: String) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.path = path
    }
}

/// Index file structure.
public struct ConversationIndex: Codable, Sendable {
    public let version: Int
    public var conversations: [ConversationIndexEntry]

    public init(version: Int = 1, conversations: [ConversationIndexEntry] = []) {
        self.version = version
        self.conversations = conversations
    }
}

