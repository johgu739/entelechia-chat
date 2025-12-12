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
            CodeBlockHeader(language: language, copied: copied) {
                copyToClipboard()
            }
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.s16)
                    .padding(.vertical, DS.s12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(DS.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r12)
                        .stroke(DS.stroke, lineWidth: 1)
                )
        )
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        
        withAnimation {
            copied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                copied = false
            }
        }
    }
}
