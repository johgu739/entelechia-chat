import Foundation

/// Lightweight view-facing snapshot of the last built Codex context (pure value type).
public struct ContextSnapshot: Equatable, Sendable {
    public let scope: ContextScopeChoice
    public let snapshotHash: String?
    public let segments: [ContextSegmentDescriptor]
    public let includedFiles: [ContextFileDescriptor]
    public let truncatedFiles: [ContextFileDescriptor]
    public let excludedFiles: [ContextFileDescriptor]
    public let totalTokens: Int
    public let totalBytes: Int
    
    public init(
        scope: ContextScopeChoice,
        snapshotHash: String?,
        segments: [ContextSegmentDescriptor],
        includedFiles: [ContextFileDescriptor],
        truncatedFiles: [ContextFileDescriptor],
        excludedFiles: [ContextFileDescriptor],
        totalTokens: Int,
        totalBytes: Int
    ) {
        self.scope = scope
        self.snapshotHash = snapshotHash
        self.segments = segments
        self.includedFiles = includedFiles
        self.truncatedFiles = truncatedFiles
        self.excludedFiles = excludedFiles
        self.totalTokens = totalTokens
        self.totalBytes = totalBytes
    }
}

public struct ContextSegmentDescriptor: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let totalTokens: Int
    public let totalBytes: Int
    public let files: [ContextFileDescriptor]
    
    public init(id: UUID = UUID(), totalTokens: Int, totalBytes: Int, files: [ContextFileDescriptor]) {
        self.id = id
        self.totalTokens = totalTokens
        self.totalBytes = totalBytes
        self.files = files
    }
}

public struct ContextFileDescriptor: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let path: String
    public let language: String?
    public let size: Int
    public let hash: String
    public let isIncluded: Bool
    public let isTruncated: Bool
    
    public init(
        id: UUID = UUID(),
        path: String,
        language: String?,
        size: Int,
        hash: String,
        isIncluded: Bool,
        isTruncated: Bool
    ) {
        self.id = id
        self.path = path
        self.language = language
        self.size = size
        self.hash = hash
        self.isIncluded = isIncluded
        self.isTruncated = isTruncated
    }
}

