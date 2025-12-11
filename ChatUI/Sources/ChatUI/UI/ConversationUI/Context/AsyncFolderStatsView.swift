import SwiftUI
import UIConnections

struct AsyncFolderStatsView: View {
    let url: URL
    @ObservedObject var viewModel: FolderStatsViewModel
    let formatFileSize: (Int64) -> String
    let formatNumber: (Int) -> String
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                InspectorSection(title: "TOTAL SIZE") {
                    Text("Loading...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            } else if let stats = viewModel.stats {
                InspectorSection(title: "TOTAL SIZE") {
                    Text(formatFileSize(stats.totalSize))
                        .font(.system(size: 13))
                }
                
                InspectorSection(title: "TOKENS") {
                    Text("~\(formatNumber(stats.totalTokens)) tokens")
                        .font(.system(size: 13))
                }
                
                if stats.totalLines > 0 {
                    InspectorSection(title: "TOTAL LINES") {
                        Text("~\(formatNumber(stats.totalLines)) lines of code")
                            .font(.system(size: 13))
                    }
                }
            }
        }
    }
}
