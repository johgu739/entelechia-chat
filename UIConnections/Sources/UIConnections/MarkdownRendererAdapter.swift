import Foundation
import Engine

/// Placeholder markdown renderer to satisfy adapter surface.
public struct MarkdownRendererAdapter {
    public init() {}

    public func render(_ markdown: String) -> [ContentBlock] {
        // Return a single text block; real implementation should parse markdown.
        return [ContentBlock(type: .text, content: markdown, language: nil)]
    }
}

