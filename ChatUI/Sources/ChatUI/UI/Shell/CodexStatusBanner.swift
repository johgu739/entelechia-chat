import SwiftUI

struct CodexStatusBanner: View {
    let icon: String
    let message: String
    let tone: CodexStatusTone
    let watcherError: String?
    
    enum CodexStatusTone {
        case success
        case warning
        case error
    }

    var body: some View {
        HStack(spacing: DS.s8) {
            Image(systemName: icon)
                .foregroundColor(accentColor)
                .font(.system(size: 12, weight: .semibold))
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
            if let watcherError = watcherError {
                Divider()
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12, weight: .semibold))
                Text(watcherError)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
        }
        .padding(DS.s8)
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(DS.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r12)
                        .stroke(accentColor.opacity(0.6), lineWidth: 1)
                )
        )
    }
    
    private var accentColor: Color {
        switch tone {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}
