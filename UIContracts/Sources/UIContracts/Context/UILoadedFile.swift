import Foundation

/// Simplified UI mirror of LoadedFile for context display.
public struct UILoadedFile: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let path: String
    public let language: String?
    public let size: Int
    public let hash: String?
    
    public init(
        id: UUID = UUID(),
        path: String,
        language: String? = nil,
        size: Int,
        hash: String? = nil
    ) {
        self.id = id
        self.path = path
        self.language = language
        self.size = size
        self.hash = hash
    }
}


