import Foundation
import UIContracts

/// Lightweight view-facing snapshot of the last built Codex context.
/// This type is now in UIContracts - this is kept for backward compatibility.
/// New code should use UIContracts.ContextSnapshot.
@available(*, deprecated, message: "Use UIContracts.ContextSnapshot instead")
public struct ContextSnapshot: Equatable {
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

@available(*, deprecated, message: "Use UIContracts.ContextSegmentDescriptor instead")
public struct ContextSegmentDescriptor: Equatable, Identifiable {
    public let id = UUID()
    public let totalTokens: Int
    public let totalBytes: Int
    public let files: [ContextFileDescriptor]
    
    public init(totalTokens: Int, totalBytes: Int, files: [ContextFileDescriptor]) {
        self.totalTokens = totalTokens
        self.totalBytes = totalBytes
        self.files = files
    }
}

@available(*, deprecated, message: "Use UIContracts.ContextFileDescriptor instead")
public struct ContextFileDescriptor: Equatable, Identifiable {
    public let id = UUID()
    public let path: String
    public let language: String?
    public let size: Int
    public let hash: String
    public let isIncluded: Bool
    public let isTruncated: Bool
    
    public init(
        path: String,
        language: String?,
        size: Int,
        hash: String,
        isIncluded: Bool,
        isTruncated: Bool
    ) {
        self.path = path
        self.language = language
        self.size = size
        self.hash = hash
        self.isIncluded = isIncluded
        self.isTruncated = isTruncated
    }
}

