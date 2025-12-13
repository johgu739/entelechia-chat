import SwiftUI

struct AskButton: View {
    let action: () -> Void
    let isEnabled: Bool
    let hasText: Bool
    
    private var isActive: Bool { isEnabled && hasText }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "sparkles")
                .foregroundColor(isActive ? .accentColor : DS.tertiaryText)
        }
        .buttonStyle(.plain)
        .disabled(!isActive)
        .frame(minWidth: 44, minHeight: 44)
        .padding(.horizontal, DS.s4)
        .contentShape(Rectangle())
        .accessibilityLabel("Ask Codex")
        .keyboardShortcut(.return, modifiers: [.option])
    }
}


