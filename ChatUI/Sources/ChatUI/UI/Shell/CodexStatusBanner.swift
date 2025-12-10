import SwiftUI
import UIConnections

struct CodexStatusBanner: View {
    @EnvironmentObject var codexStatusModel: CodexStatusModel
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: codexStatusModel.icon)
                .foregroundColor(accentColor)
                .font(.system(size: 12, weight: .semibold))
            Text(codexStatusModel.message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
            if let watcherError = workspaceViewModel.watcherError {
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
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(accentColor.opacity(0.6), lineWidth: 1)
                )
        )
    }
    
    private var accentColor: Color {
        switch codexStatusModel.tone {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}


