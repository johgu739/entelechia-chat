import SwiftUI

struct MicButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "mic")
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .padding(.horizontal, DS.s4)
        .contentShape(Rectangle())
        .accessibilityLabel("Voice input")
    }
}

