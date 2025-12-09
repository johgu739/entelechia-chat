// @EntelechiaHeaderStart
// Signifier: MarkdownView
// Substance: Operator markdown view
// Genus: UI view
// Differentia: Displays formatted markdown
// Form: Markdown rendering for operator output
// Matter: Markdown text; attributed rendering
// Powers: Display formatted markdown
// FinalCause: Present documentation/output clearly
// Relations: Serves operator UI; depends on renderer/context
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppCoreEngine
import Foundation
import AppKit

struct MarkdownDocumentView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(MarkdownRenderer.parseContent(markdown), id: \.id) { block in
                    switch block.type {
                    case .codeBlock:
                        SimpleCodeBlockView(code: block.content, language: block.language)
                    case .text:
                        Text(MarkdownRenderer.parseMarkdown(block.content))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}

private struct SimpleCodeBlockView: View {
    let code: String
    let language: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = language, !language.isEmpty {
                Text(language.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
            }
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}