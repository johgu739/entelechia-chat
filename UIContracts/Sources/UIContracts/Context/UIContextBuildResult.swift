import Foundation

/// UI mirror of ContextBuildResult.
public struct UIContextBuildResult: Sendable, Equatable {
    public let attachments: [UILoadedFile]
    public let truncatedFiles: [UILoadedFile]
    public let excludedFiles: [UIContextExclusion]
    public let totalBytes: Int
    public let totalTokens: Int
    public let encodedSegments: [UIContextSegment]
    
    public init(
        attachments: [UILoadedFile],
        truncatedFiles: [UILoadedFile],
        excludedFiles: [UIContextExclusion],
        totalBytes: Int,
        totalTokens: Int,
        encodedSegments: [UIContextSegment] = []
    ) {
        self.attachments = attachments
        self.truncatedFiles = truncatedFiles
        self.excludedFiles = excludedFiles
        self.totalBytes = totalBytes
        self.totalTokens = totalTokens
        self.encodedSegments = encodedSegments
    }
}

