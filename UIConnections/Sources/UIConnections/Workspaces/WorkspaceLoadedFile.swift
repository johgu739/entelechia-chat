// @EntelechiaHeaderStart
// Signifier: WorkspaceLoadedFile
// Substance: Loaded file value
// Genus: Workspace data model
// Differentia: Holds file content with inclusion flag
// Form: Path + content + inclusion flag
// Matter: File text data; URL
// Powers: Hold file content for context
// FinalCause: Pass file data into conversations
// Relations: Used by FileContentService/ConversationService
// CausalityType: Material
// @EntelechiaHeaderEnd

import Foundation
import AppCoreEngine

public struct WorkspaceLoadedFile: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let url: URL
    public let content: String
    public let fileKind: FileKind?
    public var isIncludedInContext: Bool
    public let byteCount: Int
    public let tokenEstimate: Int
    public let originalByteCount: Int?
    public let originalTokenEstimate: Int?
    public let contextNote: String?
    public let exclusionReason: ContextExclusionReason?
    
    public static func == (lhs: WorkspaceLoadedFile, rhs: WorkspaceLoadedFile) -> Bool {
        lhs.id == rhs.id
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        content: String,
        fileKind: FileKind? = nil,
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
        self.fileKind = fileKind
        self.isIncludedInContext = isIncludedInContext
        self.byteCount = byteCount ?? content.utf8.count
        self.tokenEstimate = tokenEstimate ?? TokenEstimator.estimateTokens(for: content)
        self.originalByteCount = originalByteCount
        self.originalTokenEstimate = originalTokenEstimate
        self.contextNote = contextNote
        self.exclusionReason = exclusionReason
    }
    
    public var iconName: String {
        guard let fileKind = fileKind else { return "doc" }
        switch fileKind {
        case .sourceCode, .text:
            return "doc.text"
        case .image:
            return "photo"
        case .pdf:
            return "doc.fill"
        case .other:
            return "doc"
        }
    }
}

