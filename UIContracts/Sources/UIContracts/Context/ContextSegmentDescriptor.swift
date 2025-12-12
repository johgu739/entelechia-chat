import Foundation

public struct ContextSegmentDescriptor: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let totalTokens: Int
    public let totalBytes: Int
    public let files: [ContextFileDescriptor]
    
    public init(
        id: UUID,
        totalTokens: Int,
        totalBytes: Int,
        files: [ContextFileDescriptor]
    ) {
        self.id = id
        self.totalTokens = totalTokens
        self.totalBytes = totalBytes
        self.files = files
    }
}

