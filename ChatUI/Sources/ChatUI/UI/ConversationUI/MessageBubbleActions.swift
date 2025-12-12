import SwiftUI
import AppKit

struct MessageBubbleActions: View {
    let text: String
    let isAssistant: Bool
    let onViewContext: (() -> Void)?
    let onReask: (() -> Void)?
    
    @State private var didCopy = false
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DS.s10) {
            copyButton
            if let onViewContext, isAssistant {
                secondaryButton(title: "View context", action: onViewContext)
            }
            if let onReask, isAssistant {
                secondaryButton(title: "Re-ask", action: onReask)
            }
            Spacer()
        }
    }
    
    private var copyButton: some View {
        Button(
            action: { copyToClipboard(text) },
            label: {
                Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DS.s8)
                    .padding(.vertical, DS.s4)
                    .background(RoundedRectangle(cornerRadius: DS.r12).fill(DS.stroke.opacity(0.2)))
            }
        )
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
    
    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(
            action: action,
            label: {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DS.s8)
                    .padding(.vertical, DS.s4)
                    .background(RoundedRectangle(cornerRadius: DS.r12).fill(DS.stroke.opacity(0.2)))
            }
        )
        .buttonStyle(.plain)
    }
    
    private func copyToClipboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.25)) {
            didCopy = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.25)) {
                didCopy = false
            }
        }
    }
}
