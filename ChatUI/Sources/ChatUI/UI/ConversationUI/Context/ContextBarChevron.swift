import SwiftUI

struct ContextBarChevron: View {
    @Binding var isCollapsed: Bool
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isCollapsed.toggle()
            }
        } label: {
            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCollapsed ? "Expand context summary" : "Collapse context summary")
        .frame(minWidth: 44, minHeight: 44)
    }
}

