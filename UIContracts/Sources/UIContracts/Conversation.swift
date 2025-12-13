import Foundation

/// Conversation for UI display (simplified, pure value type).
public struct Conversation: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let contextFilePaths: [String]
    
    public init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        contextFilePaths: [String] = []
    ) {
        self.id = id
        self.title = title
        self.contextFilePaths = contextFilePaths
    }
}


