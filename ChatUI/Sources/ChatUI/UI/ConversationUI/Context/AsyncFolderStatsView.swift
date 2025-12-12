import SwiftUI
import UIContracts

struct AsyncFolderStatsView: View {
    let stats: UIContracts.FolderStats?
    let isLoading: Bool
    let formatFileSize: (Int64) -> String
    let formatNumber: (Int) -> String
    
    var body: some View {
        Group {
            if isLoading {
                InspectorSection(title: "TOTAL SIZE") {
                    Text("Loading...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            } else if let stats = stats {
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
