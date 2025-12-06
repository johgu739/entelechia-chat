import Foundation

/// Message model.
public struct Message: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let role: MessageRole
    public let text: String
    public let createdAt: Date
    public var attachments: [Attachment]

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

