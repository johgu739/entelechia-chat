// @EntelechiaHeaderStart
// Substance: Content block value
// Genus: Message component
// Differentia: Typed chunk of message payload
// Form: Type + content rules
// Matter: Block payload (text/code/etc.)
// Powers: Represent structured parts of messages
// FinalCause: Structure message content
// Relations: Part of Message; used in rendering
// CausalityType: Material
// @EntelechiaHeaderEnd

import Foundation

/// Shared model for markdown content blocks
struct ContentBlock: Identifiable {
    let id = UUID()
    let type: BlockType
    let content: String
    let language: String?
    
    enum BlockType {
        case text
        case codeBlock
    }
}
