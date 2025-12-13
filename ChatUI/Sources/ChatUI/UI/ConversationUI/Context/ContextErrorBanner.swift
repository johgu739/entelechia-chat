import SwiftUI

struct ContextErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: DS.s8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.warningColor)
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
                .fill(.thinMaterial)
                .shadow(color: .black.opacity(0.04), radius: 1)
        )
    }
}
