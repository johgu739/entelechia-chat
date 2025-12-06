import Foundation

/// Loaded file contents for context building (UI-free, portable).
public struct LoadedFile: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let url: URL
    public let content: String
    /// Identifier for file type (e.g., UTI or MIME). Keep as string for portability.
    public let fileTypeIdentifier: String?
    public var isIncludedInContext: Bool
    public let byteCount: Int
    public let tokenEstimate: Int
    public let originalByteCount: Int?
    public let originalTokenEstimate: Int?
    public let contextNote: String?
    public let exclusionReason: ContextExclusionReason?

    public static func == (lhs: LoadedFile, rhs: LoadedFile) -> Bool {
        lhs.id == rhs.id
    }

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        content: String,
        fileTypeIdentifier: String? = nil,
        isIncludedInContext: Bool = true,
        byteCount: Int? = nil,
        tokenEstimate: Int? = nil,
        originalByteCount: Int? = nil,
        originalTokenEstimate: Int? = nil,
        contextNote: String? = nil,
        exclusionReason: ContextExclusionReason? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.content = content
        self.fileTypeIdentifier = fileTypeIdentifier
        self.isIncludedInContext = isIncludedInContext
        self.byteCount = byteCount ?? content.utf8.count
        self.tokenEstimate = tokenEstimate ?? TokenEstimator.estimateTokens(for: content)
        self.originalByteCount = originalByteCount
        self.originalTokenEstimate = originalTokenEstimate
        self.contextNote = contextNote
        self.exclusionReason = exclusionReason
    }
}

public enum ContextExclusionReason: Equatable, Sendable {
    case exceedsPerFileBytes(limit: Int)
    case exceedsPerFileTokens(limit: Int)
    case exceedsTotalBytes(limit: Int)
    case exceedsTotalTokens(limit: Int)
}

