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
import UniformTypeIdentifiers
import AppComposition

struct WorkspaceLoadedFile: Identifiable, Equatable {
    let id: UUID
    let name: String
    let url: URL
    let content: String
    let fileType: UTType?
    var isIncludedInContext: Bool
    let byteCount: Int
    let tokenEstimate: Int
    let originalByteCount: Int?
    let originalTokenEstimate: Int?
    let contextNote: String?
    let exclusionReason: ContextExclusionReason?
    
    static func == (lhs: WorkspaceLoadedFile, rhs: WorkspaceLoadedFile) -> Bool {
        lhs.id == rhs.id
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        content: String,
        fileType: UTType? = nil,
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
        self.fileType = fileType
        self.isIncludedInContext = isIncludedInContext
        self.byteCount = byteCount ?? content.utf8.count
        self.tokenEstimate = tokenEstimate ?? TokenEstimator.estimateTokens(for: content)
        self.originalByteCount = originalByteCount
        self.originalTokenEstimate = originalTokenEstimate
        self.contextNote = contextNote
        self.exclusionReason = exclusionReason
    }
    
    var iconName: String {
        guard let fileType = fileType else { return "doc" }
        
        if fileType.conforms(to: .sourceCode) {
            return "doc.text"
        } else if fileType.conforms(to: .image) {
            return "photo"
        } else if fileType.conforms(to: .pdf) {
            return "doc.fill"
        } else if fileType.conforms(to: .text) {
            return "doc.text"
        } else {
            return "doc"
        }
    }
}
