import SwiftUI
import AppKit

struct InputTextArea: View {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat
    @FocusState.Binding var isFocused: Bool
    
    let minEditorHeight: CGFloat
    let maxEditorHeight: CGFloat
    let onSend: () -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Message Aletheon")
                    .foregroundColor(DS.secondaryText)
                    .padding(.vertical, DS.s8 + 2)
                    .padding(.horizontal, DS.s8)
                    .allowsHitTesting(false)
            }
            
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(DS.body)
                .padding(.vertical, DS.s8 - 2)
                .padding(.horizontal, DS.s8 - 4)
                .frame(
                    minHeight: minEditorHeight,
                    maxHeight: min(maxEditorHeight, measuredHeight),
                    alignment: .top
                )
                .focused($isFocused)
                .background(
                    MeasuredText(
                        text: text.isEmpty ? " " : text,
                        width: nil,
                        font: DS.body,
                        padding: EdgeInsets(
                            top: DS.s8 - 2,
                            leading: DS.s8 - 4,
                            bottom: DS.s8 - 2,
                            trailing: DS.s8 - 4
                        )
                    )
                    .opacity(0)
                )
                .onPreferenceChange(TextHeightKey.self) { height in
                    let clamped = max(38, min(height, maxEditorHeight))
                    if abs(clamped - measuredHeight) > 0.5 {
                        measuredHeight = clamped
                    }
                }
                .onKeyPress(.return) {
                    // Check if Shift is held down using NSEvent
                    let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                    if isShiftPressed {
                        // Shift+Return: Allow newline (default behavior)
                        return .ignored
                    } else {
                        // Return: Send message
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            onSend()
                        }
                        return .handled
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

