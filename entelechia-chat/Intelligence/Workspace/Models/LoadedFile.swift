// @EntelechiaHeaderStart
// Signifier: LoadedFile
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

struct LoadedFile: Identifiable, Equatable {
    let id: UUID
    let name: String
    let url: URL
    let content: String
    let fileType: UTType?
    var isIncludedInContext: Bool
    
    static func == (lhs: LoadedFile, rhs: LoadedFile) -> Bool {
        lhs.id == rhs.id
    }
    
    init(id: UUID = UUID(), name: String, url: URL, content: String, fileType: UTType? = nil, isIncludedInContext: Bool = true) {
        self.id = id
        self.name = name
        self.url = url
        self.content = content
        self.fileType = fileType
        self.isIncludedInContext = isIncludedInContext
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
