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
    let onAskCodex: (() -> Void)?
    let isAskEnabled: Bool
    let currentTarget: String?
    let sendShortcut: String
    let askShortcut: String
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let currentTarget, !currentTarget.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11, weight: .semibold))
                    Text(currentTarget)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                Button(action: { onAttachFile() }) {
                    Image(systemName: "plus")
                        .foregroundColor(.chatIcon)
                        .font(.system(size: 16, weight: .medium))
                        .accessibilityLabel("Attach file")
                }
                .buttonStyle(.plain)
                
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Message Codex…")
                            .foregroundColor(.chatPlaceholder)
                            .font(.system(size: 15))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 15))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                        .frame(minHeight: 36, maxHeight: 120, alignment: .top)
                        .fixedSize(horizontal: false, vertical: true)
                        .focused($isFocused)
                        .onChange(of: text) { oldValue, newValue in
                            // Enter sends when Command is not held, matching chat-style input
                            if newValue.contains("\n") && !oldValue.contains("\n") {
                                if let event = NSApp.currentEvent, !event.modifierFlags.contains(.command) {
                                    let trimmed = text.replacingOccurrences(of: "\n", with: "")
                                    text = trimmed
                                    if !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        send()
                                    }
                                }
                            }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 6) {
                    if let onAskCodex {
                        Button(action: { ask(onAskCodex) }) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isAskEnabled ? .chatIcon : .accentColor)
                                .accessibilityLabel("Ask Codex")
                        }
                        .buttonStyle(.plain)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isAskEnabled)
                    }
                    
                    Button(action: { send() }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .chatIcon : .accentColor)
                            .font(.system(size: 16, weight: .semibold))
                            .accessibilityLabel("Send")
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.chatInputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.chatInputBorder, lineWidth: 1)
                    )
            )
            .frame(minHeight: 52, maxHeight: 180, alignment: .top)
        }
        .padding(.horizontal, 4)
        .onAppear { isFocused = true }
    }
    
    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend()
        text = ""
    }

    private func ask(_ handler: () -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        handler()
        text = ""
    }
}
