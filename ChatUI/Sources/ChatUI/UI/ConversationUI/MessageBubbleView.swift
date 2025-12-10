// @EntelechiaHeaderStart
// Signifier: MessageBubbleView
// Substance: Message bubble UI
// Genus: UI view
// Differentia: Renders single message with role styling
// Form: Bubble layout and styling
// Matter: Message content; role styling
// Powers: Render single message appropriately
// FinalCause: Visually differentiate messages
// Relations: Serves ChatView
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import UIConnections
import AppKit

struct MessageBubbleView: View {
    let message: Message
    let isAssistant: Bool
    var contextSummary: String?
    var errorMessage: String?
    var onViewContext: (() -> Void)?
    var onReask: (() -> Void)?
    @State private var didCopy = false
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            if isAssistant { Spacer().frame(maxWidth: .infinity) }
            content
            if !isAssistant { Spacer().frame(maxWidth: .infinity) }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(alignment: isAssistant ? .leading : .trailing, spacing: 6) {
            // Role + timestamp line
            HStack(spacing: 6) {
                Text(isAssistant ? "Assistant" : "You")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(message.createdAt, style: .time)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: isAssistant ? .leading : .trailing)
            
            // Bubble
            VStack(alignment: .leading, spacing: 8) {
                if let contextSummary, !contextSummary.isEmpty, isAssistant {
                    Text(contextSummary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                if let errorMessage, !errorMessage.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12, weight: .bold))
                        Text(errorMessage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
                MarkdownMessageView(content: message.text)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isAssistant ? Color(nsColor: .textBackgroundColor) : Color(white: 0.92))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .frame(maxWidth: 720, alignment: .leading)
            
            // Bottom actions
            HStack(spacing: 10) {
                Button(action: { copyToClipboard(message.text) }) {
                    Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .scaleEffect(isHovered ? 1.03 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                
                if let onViewContext, isAssistant {
                    Button("View context", action: onViewContext)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                        .buttonStyle(.plain)
                }
                
                if let onReask, isAssistant {
                    Button("Re-ask", action: onReask)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                        .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: isAssistant ? .leading : .trailing)
        }
        .frame(maxWidth: 760, alignment: isAssistant ? .leading : .trailing)
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.25)) {
            didCopy = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(.easeInOut(duration: 0.25)) {
                didCopy = false
            }
        }
    }
}