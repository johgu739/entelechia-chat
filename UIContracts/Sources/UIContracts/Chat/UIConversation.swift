import Foundation

/// UI mirror of Conversation.
public struct UIConversation: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date
    public let messages: [UIMessage]
    public let contextFilePaths: [String]
    public let contextDescriptorIDs: [UUID]?
    
    public init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [UIMessage] = [],
        contextFilePaths: [String] = [],
        contextDescriptorIDs: [UUID]? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
        self.contextFilePaths = contextFilePaths
        self.contextDescriptorIDs = contextDescriptorIDs
    }
}


