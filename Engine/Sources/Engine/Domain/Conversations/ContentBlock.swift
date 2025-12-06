import Foundation

/// Shared model for markdown content blocks (pure, no rendering deps).
public struct ContentBlock: Identifiable, Sendable {
    public let id: UUID
    public let type: BlockType
    public let content: String
    public let language: String?

    public init(
        id: UUID = UUID(),
        type: BlockType,
        content: String,
        language: String? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.language = language
    }

    public enum BlockType: Sendable {
        case text
        case codeBlock
    }
}

