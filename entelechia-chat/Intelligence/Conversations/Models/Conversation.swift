// @EntelechiaHeaderStart
// Signifier: Conversation
// Substance: Conversation aggregate
// Genus: Conversation entity
// Differentia: Captures dialogue plus context paths
// Form: Messages + metadata + context paths
// Matter: Message list; title; timestamps; paths
// Powers: Encapsulate dialogue state
// FinalCause: Represent and persist a dialogue tied to files
// Relations: Used by services/stores/UI
// CausalityType: Material
// @EntelechiaHeaderEnd

import Foundation
import SwiftUI
import Combine

/// Conversation model - ObservableObject for SwiftUI, Codable for persistence
final class Conversation: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var title: String
    let createdAt: Date
    @Published var updatedAt: Date
    @Published var messages: [Message]
    @Published var contextFilePaths: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case updatedAt
        case messages
        case contextFilePaths
    }
    
    init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [Message] = [],
        contextFilePaths: [String] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
        self.contextFilePaths = contextFilePaths
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        messages = try container.decode([Message].self, forKey: .messages)
        contextFilePaths = try container.decode([String].self, forKey: .contextFilePaths)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(messages, forKey: .messages)
        try container.encode(contextFilePaths, forKey: .contextFilePaths)
    }
    
    /// Compute summary title from first user message
    var summaryTitle: String {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let words = firstUserMessage.text.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            let preview = words.prefix(8).joined(separator: " ")
            return preview.isEmpty ? "New Conversation" : preview
        }
        return "New Conversation"
    }
    
    /// Convenience property for context URL (first path)
    var contextURL: URL? {
        contextFilePaths.first.flatMap { URL(fileURLWithPath: $0) }
    }
}

/// Index entry for conversation metadata
struct ConversationIndexEntry: Codable, Equatable {
    let id: UUID
    let title: String
    let updatedAt: Date
    let path: String
}

/// Index file structure
struct ConversationIndex: Codable {
    let version: Int
    var conversations: [ConversationIndexEntry]
    
    init(version: Int = 1, conversations: [ConversationIndexEntry] = []) {
        self.version = version
        self.conversations = conversations
    }
}
