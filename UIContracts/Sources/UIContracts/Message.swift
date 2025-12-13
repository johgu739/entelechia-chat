import Foundation

/// Message model for UI display (pure value type).
public struct Message: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let role: MessageRole
    public let text: String
    public let createdAt: Date
    public let attachments: [Attachment]
    
    public init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        createdAt: Date = Date(),
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.attachments = attachments
    }
}

public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

/// Attachment for messages (simplified for UI).
public struct Attachment: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let url: URL?
    
    public init(id: UUID = UUID(), name: String, url: URL? = nil) {
        self.id = id
        self.name = name
        self.url = url
    }
}


