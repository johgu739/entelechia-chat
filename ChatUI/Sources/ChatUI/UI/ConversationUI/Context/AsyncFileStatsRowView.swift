import SwiftUI
import UIConnections

struct AsyncFileStatsRowView: View {
    let url: URL
    @ObservedObject var viewModel: FileStatsViewModel
    let formatFileSize: (Int64) -> String
    let formatNumber: (Int) -> String
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                Text("Loading...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: DS.s4) {
                    if let size = viewModel.size {
                        Text("\(formatFileSize(size)) · ~\(formattedTokens)")
                            .font(.system(size: 13))
                    }
                    
                    if let lineCount = viewModel.lineCount {
                        Text("\(lineCount) lines")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if viewModel.size == nil && viewModel.lineCount == nil {
                        Text("Unknown")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var formattedTokens: String {
        formatNumber(viewModel.tokenEstimate ?? 0)
    }
}
