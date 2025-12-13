import SwiftUI

struct InputAttachButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .padding(.horizontal, DS.s4)
        .contentShape(Rectangle())
        .accessibilityLabel("Attach")
    }
}


