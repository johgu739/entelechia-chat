import Foundation

/// Simplified UI mirror of ContextSegment.
public struct UIContextSegment: Sendable, Equatable {
    public let files: [UILoadedFile]
    public let totalTokens: Int
    public let totalBytes: Int
    
    public init(
        files: [UILoadedFile],
        totalTokens: Int,
        totalBytes: Int
    ) {
        self.files = files
        self.totalTokens = totalTokens
        self.totalBytes = totalBytes
    }
}


