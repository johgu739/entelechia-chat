// @EntelechiaHeaderStart
// Signifier: CodeBlockView
// Substance: Code block UI
// Genus: UI view
// Differentia: Displays code segments
// Form: Monospaced styling and copy affordance
// Matter: Code strings
// Powers: Render code segments
// FinalCause: Display code outputs clearly
// Relations: Serves MarkdownMessageView/ChatView
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI

struct CodeBlockView: View {
    let code: String
    let language: String?
    
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                if let language = language, !language.isEmpty {
                    Text(language.uppercased())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    copyToClipboard()
                }) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.96))
            
            // Code content
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
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        
        withAnimation {
            copied = true
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            withAnimation {
                copied = false
            }
        }
    }
}
