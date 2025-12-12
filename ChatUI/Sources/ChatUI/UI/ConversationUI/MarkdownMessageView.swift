// @EntelechiaHeaderStart
// Signifier: MarkdownMessageView
// Substance: Markdown message UI
// Genus: UI view
// Differentia: Renders markdown content
// Form: Markdown rendering and layout
// Matter: Message text; attributed markdown
// Powers: Render markdown safely
// FinalCause: Present rich message text
// Relations: Serves ChatView
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppKit

struct MarkdownMessageView: View {
    let content: String
    @State private var didCopy = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.s8) {
            contentBlocks
            copyRow
        }
        .onHover { isHovered = $0 }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Show "Copied" feedback
        withAnimation(.easeInOut(duration: 0.25)) {
            didCopy = true
        }
        
        // Hide after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.25)) {
                didCopy = false
            }
        }
    }
    
    private var contentBlocks: some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            ForEach(MarkdownRenderer.parseContent(content), id: \.id) { block in
                switch block.type {
                case .codeBlock:
                    CodeBlockView(code: block.content, language: block.language)
                case .text:
                    Text(MarkdownRenderer.parseMarkdown(block.content))
                        .textSelection(.enabled)
                        .font(DS.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, DS.s4 / 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DS.s4)
    }
    
    private var copyRow: some View {
        HStack {
            Spacer()
            HStack(spacing: DS.s6) {
                if didCopy {
                    Text("Copied")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                
                Button(
                    action: { copyToClipboard(content) },
                    label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: DS.s20, height: DS.s20)
                            .contentShape(Rectangle())
                            .scaleEffect(isHovered ? 1.05 : 1.0)
                            .opacity(isHovered ? 0.8 : 0.6)
                    }
                )
                .buttonStyle(.plain)
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.25), value: didCopy)
        }
    }
}
