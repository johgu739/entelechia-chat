import Foundation

/// Context build result for UI display (simplified, pure value type).
public struct ContextBuildResult: Equatable, Sendable {
    public let attachments: [LoadedFileView]
    public let truncatedFiles: [LoadedFileView]
    public let excludedFiles: [ContextExclusionView]
    public let totalBytes: Int
    public let totalTokens: Int
    public let budget: ContextBudgetView
    
    public init(
        attachments: [LoadedFileView],
        truncatedFiles: [LoadedFileView],
        excludedFiles: [ContextExclusionView],
        totalBytes: Int,
        totalTokens: Int,
        budget: ContextBudgetView
    ) {
        self.attachments = attachments
        self.truncatedFiles = truncatedFiles
        self.excludedFiles = excludedFiles
        self.totalBytes = totalBytes
        self.totalTokens = totalTokens
        self.budget = budget
    }
}

/// Loaded file view for UI display (simplified from domain LoadedFile).
public struct LoadedFileView: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let url: URL
    public let byteCount: Int
    public let tokenEstimate: Int
    public let contextNote: String?
    
    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        byteCount: Int,
        tokenEstimate: Int,
        contextNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.byteCount = byteCount
        self.tokenEstimate = tokenEstimate
        self.contextNote = contextNote
    }
}

/// Context exclusion view for UI display.
public struct ContextExclusionView: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let file: LoadedFileView
    public let reason: ContextExclusionReasonView
    
    public init(id: UUID = UUID(), file: LoadedFileView, reason: ContextExclusionReasonView) {
        self.id = id
        self.file = file
        self.reason = reason
    }
}

/// Context exclusion reason for UI display.
public enum ContextExclusionReasonView: Equatable, Sendable {
    case exceedsPerFileBytes(limit: Int)
    case exceedsPerFileTokens(limit: Int)
    case exceedsTotalBytes(limit: Int)
    case exceedsTotalTokens(limit: Int)
}

/// Context budget view for UI display.
public struct ContextBudgetView: Equatable, Sendable {
    public let maxPerFileBytes: Int
    public let maxPerFileTokens: Int
    public let maxTotalBytes: Int
    public let maxTotalTokens: Int
    
    public init(
        maxPerFileBytes: Int,
        maxPerFileTokens: Int,
        maxTotalBytes: Int,
        maxTotalTokens: Int
    ) {
        self.maxPerFileBytes = maxPerFileBytes
        self.maxPerFileTokens = maxPerFileTokens
        self.maxTotalBytes = maxTotalBytes
        self.maxTotalTokens = maxTotalTokens
    }
}

