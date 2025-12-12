import Foundation

/// UI mirror of Message.
public struct UIMessage: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let role: UIMessageRole
    public let text: String
    public let createdAt: Date
    public let attachments: [UIAttachment]
    
    public init(
        id: UUID = UUID(),
        role: UIMessageRole,
        text: String,
        createdAt: Date = Date(),
        attachments: [UIAttachment] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.attachments = attachments
    }
}

