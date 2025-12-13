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

