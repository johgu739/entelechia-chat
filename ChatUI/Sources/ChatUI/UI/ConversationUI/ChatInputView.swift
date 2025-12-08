// @EntelechiaHeaderStart
// Signifier: ChatInputView
// Substance: Input accident
// Genus: UI control
// Differentia: Captures chat input
// Form: TextField and send handling
// Matter: User text; send actions
// Powers: Capture and dispatch user messages
// FinalCause: Initiate conversation acts
// Relations: Serves ChatView; depends on VM
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppKit

// MARK: - ChatGPT Color Extensions

extension Color {
    static let chatInputBackground = Color(red: 247/255, green: 247/255, blue: 248/255)
    static let chatInputBorder = Color(red: 229/255, green: 229/255, blue: 231/255)
    static let chatPlaceholder = Color(red: 161/255, green: 161/255, blue: 167/255)
    static let chatIcon = Color(red: 153/255, green: 153/255, blue: 153/255)
}

struct ChatInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    let onAttachFile: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Plus button
            Button(action: {
                onAttachFile()
            }) {
                Image(systemName: "plus")
                    .foregroundColor(.chatIcon)
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.plain)
            
            // Text area
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Type a message…")
                        .foregroundColor(.chatPlaceholder)
                        .font(.system(size: 15))
                        .padding(.vertical, 11)
                        .padding(.horizontal, 4)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 15))
                    .padding(.vertical, 8)
                    .frame(minHeight: 44, maxHeight: 120)
                    .focused($isFocused)
                    .onChange(of: text) { oldValue, newValue in
                        // Handle Enter key press (without Command modifier)
                        if newValue.contains("\n") && !oldValue.contains("\n") {
                            // Check if Command key is NOT pressed
                            if let event = NSApp.currentEvent, !event.modifierFlags.contains(.command) {
                                // Remove the newline and send
                                let trimmed = text.replacingOccurrences(of: "\n", with: "")
                                text = trimmed
                                if !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    send()
                                }
                            }
                        }
                    }
            }
            
            // Send button
            Button(action: {
                send()
            }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .chatIcon : .accentColor)
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.chatInputBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.chatInputBorder, lineWidth: 1)
        )
        .cornerRadius(22)
        .onAppear {
            // Focus on appear - already on main thread in SwiftUI
            isFocused = true
        }
    }
    
    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend()
        text = ""
    }
}
