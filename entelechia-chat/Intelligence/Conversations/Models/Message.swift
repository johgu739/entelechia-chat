// @EntelechiaHeaderStart
// Signifier: Message
// Substance: Message entity
// Genus: Conversation component
// Differentia: Single utterance with role and content
// Form: Role + text/content blocks
// Matter: Text; role; content blocks
// Powers: Represent a single utterance
// FinalCause: Carry user/assistant communication
// Relations: Part of Conversation; used by services/UI
// CausalityType: Material
// @EntelechiaHeaderEnd

import Foundation

/// Message model
struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let text: String
    let createdAt: Date
    var attachments: [Attachment]
    
    init(
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

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}
