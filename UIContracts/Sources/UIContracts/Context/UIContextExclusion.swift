import Foundation

/// Simplified UI mirror of ContextExclusion.
public struct UIContextExclusion: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let file: UILoadedFile
    public let reason: String
    
    public init(
        id: UUID = UUID(),
        file: UILoadedFile,
        reason: String
    ) {
        self.id = id
        self.file = file
        self.reason = reason
    }
}

