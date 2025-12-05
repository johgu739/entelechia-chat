// @EntelechiaHeaderStart
// Substance: Operator app models
// Genus: Data models
// Differentia: Represent operator entities
// Form: Structures for navigator/editor/tool state
// Matter: Model records for operator domain
// Powers: Represent operator domain data
// FinalCause: Give structure to operator UI state
// Relations: Used by operator services and views
// CausalityType: Material
// @EntelechiaHeaderEnd

import Foundation

enum NavigatorSelection: Equatable {
    case file(URL)
    case codexSession(UUID)
    case daemon(UUID)
    case logStream(String)
    case patch(UUID)
    case none
}

struct EditorTab: Identifiable, Equatable {
    enum ContentType: Equatable {
        case file(URL)
        case chat(UUID)
        case markdown(String)
        case patch(UUID)
        case terminal(String)
    }

    let id: UUID
    var title: String
    var content: ContentType

    init(id: UUID = UUID(), title: String, content: ContentType) {
        self.id = id
        self.title = title
        self.content = content
    }
    
    static func == (lhs: EditorTab, rhs: EditorTab) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.content == rhs.content
    }
}