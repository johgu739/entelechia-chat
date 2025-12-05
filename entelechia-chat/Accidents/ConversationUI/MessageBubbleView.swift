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
import AppKit

struct MessageBubbleView: View {
    let message: Message
    @State private var didCopy = false
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Spacer()
                .frame(maxWidth: .infinity)
            
            VStack(alignment: .trailing, spacing: 4) {
                // Bubble
                Text(message.text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(white: 0.92))
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                    .frame(maxWidth: 500, alignment: .trailing)
                
                // Bottom row with timestamp and copy button (ChatGPT/Cursor style)
                HStack(spacing: 8) {
                    Text(message.createdAt, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    // Copy button with "Copied" feedback
                    HStack(spacing: 6) {
                        if didCopy {
                            Text("Copied")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                        
                        Button(action: {
                            copyToClipboard(message.text)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                                .scaleEffect(isHovered ? 1.05 : 1.0)
                                .opacity(isHovered ? 0.8 : 0.6)
                        }
                        .buttonStyle(.plain)
                    }
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                    .animation(.easeInOut(duration: 0.25), value: didCopy)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .onHover { hovering in
            isHovered = hovering
        }
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
}