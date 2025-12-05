// @EntelechiaHeaderStart
// Substance: Markdown rendering instrument
// Genus: Text rendering helper
// Differentia: Transforms markdown to attributed text
// Form: Conversion/rendering rules
// Matter: Markdown strings; attributed output
// Powers: Render markdown safely
// FinalCause: Present rich text for messages
// Relations: Serves UI accidents; depends on formatting libs
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation
import SwiftUI
import AppKit

struct MarkdownRenderer {
    /// Parse markdown content into blocks (text and code blocks)
    static func parseContent(_ markdown: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let codeBlockPattern = #"```(\w+)?\n([\s\S]*?)```"#
        
        guard let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) else {
            return [ContentBlock(type: .text, content: markdown, language: nil)]
        }
        
        let nsString = markdown as NSString
        let matches = regex.matches(in: markdown, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var lastIndex = 0
        
        for match in matches {
            // Add text before code block
            if match.range.location > lastIndex {
                let textRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                let text = nsString.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(ContentBlock(type: .text, content: text, language: nil))
                }
            }
            
            // Add code block
            if match.numberOfRanges >= 3 {
                let languageRange = match.range(at: 1)
                let codeRange = match.range(at: 2)
                
                let language = languageRange.location != NSNotFound && languageRange.length > 0
                    ? nsString.substring(with: languageRange)
                    : nil
                
                let code = nsString.substring(with: codeRange)
                blocks.append(ContentBlock(type: .codeBlock, content: code, language: language))
            }
            
            lastIndex = match.range.location + match.range.length
        }
        
        // Add remaining text
        if lastIndex < nsString.length {
            let textRange = NSRange(location: lastIndex, length: nsString.length - lastIndex)
            let text = nsString.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(ContentBlock(type: .text, content: text, language: nil))
            }
        }
        
        // If no code blocks found, return entire content as text
        if blocks.isEmpty {
            blocks.append(ContentBlock(type: .text, content: markdown, language: nil))
        }
        
        return blocks
    }
    
    static func parseMarkdown(_ markdown: String) -> AttributedString {
        var attributedString = AttributedString(markdown)
        
        // Apply base styling
        attributedString.font = .system(size: 15, weight: .regular, design: .default)
        attributedString.foregroundColor = .primary
        
        // Parse markdown patterns using NSMutableAttributedString for easier manipulation
        let nsMutableString = NSMutableAttributedString(attributedString)
        
        parseLinks(in: nsMutableString)
        parseHeaders(in: nsMutableString)
        parseItalic(in: nsMutableString)
        parseBold(in: nsMutableString)
        parseInlineCode(in: nsMutableString)
        
        return AttributedString(nsMutableString)
    }
    
    private static func parseInlineCode(in attributedString: NSMutableAttributedString) {
        let pattern = #"`([^`]+)`"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        
        let string = attributedString.string as NSString
        let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
        
        for match in matches.reversed() {
            if match.numberOfRanges >= 2 {
                let fullRange = match.range
                attributedString.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                    .backgroundColor: NSColor(white: 0.95, alpha: 1.0)
                ], range: fullRange)
            }
        }
    }
    
    private static func parseBold(in attributedString: NSMutableAttributedString) {
        let pattern = #"\*\*([^*]+)\*\*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        
        let string = attributedString.string as NSString
        let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
        
        for match in matches.reversed() {
            let fullRange = match.range
            attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 15, weight: .semibold), range: fullRange)
        }
    }
    
    private static func parseItalic(in attributedString: NSMutableAttributedString) {
        let pattern = #"(?<!\*)\*([^*]+)\*(?!\*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        
        let string = attributedString.string as NSString
        let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
        
        for match in matches.reversed() {
            let fullRange = match.range
            let font = NSFont.systemFont(ofSize: 15)
            let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            attributedString.addAttribute(.font, value: italicFont, range: fullRange)
        }
    }
    
    private static func parseHeaders(in attributedString: NSMutableAttributedString) {
        let patterns: [(String, CGFloat, NSFont.Weight)] = [
            (#"^### (.*)$"#, 18, .semibold),
            (#"^## (.*)$"#, 20, .semibold),
            (#"^# (.*)$"#, 24, .bold)
        ]
        
        let string = attributedString.string as NSString
        
        for (pattern, size, weight) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { continue }
            let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
            
            for match in matches.reversed() {
                let headerRange = match.range
                attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: weight), range: headerRange)
            }
        }
    }
    
    private static func parseLinks(in attributedString: NSMutableAttributedString) {
        let pattern = #"\[([^\]]+)\]\(([^\)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        
        let string = attributedString.string as NSString
        let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
        
        for match in matches.reversed() {
            if match.numberOfRanges >= 3 {
                let linkRange = match.range
                let urlRange = match.range(at: 2)
                let urlString = string.substring(with: urlRange)
                
                if let url = URL(string: urlString) {
                    attributedString.addAttributes([
                        .link: url,
                        .foregroundColor: NSColor.systemBlue
                    ], range: linkRange)
                }
            }
        }
    }
}
