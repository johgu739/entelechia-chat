import SwiftUI

struct SendButton: View {
    let action: () -> Void
    let hasText: Bool
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(hasText ? .accentColor : DS.tertiaryText)
        }
        .buttonStyle(.plain)
        .disabled(!hasText)
        .frame(minWidth: 44, minHeight: 44)
        .padding(.horizontal, DS.s4)
        .contentShape(Rectangle())
        .accessibilityLabel("Send message")
        .keyboardShortcut(.return, modifiers: [.command])
    }
}


