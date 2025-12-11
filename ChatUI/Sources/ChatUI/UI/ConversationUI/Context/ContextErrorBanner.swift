import SwiftUI

struct ContextErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: DS.s8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(3)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.s10)
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.9))
                .shadow(radius: DS.s4)
        )
    }
}
