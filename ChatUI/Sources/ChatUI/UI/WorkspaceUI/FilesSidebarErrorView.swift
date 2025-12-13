import SwiftUI

struct FilesSidebarErrorView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.warningColor)
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.s12)
        .padding(.vertical, DS.s8)
        .background(AppTheme.warningColor.opacity(0.1))
        .overlay(Divider(), alignment: .bottom)
    }
}

