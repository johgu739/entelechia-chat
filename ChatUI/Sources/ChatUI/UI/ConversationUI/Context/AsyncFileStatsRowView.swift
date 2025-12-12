import SwiftUI

struct AsyncFileStatsRowView: View {
    let size: Int64?
    let lineCount: Int?
    let tokenEstimate: Int?
    let isLoading: Bool
    let formatFileSize: (Int64) -> String
    let formatNumber: (Int) -> String
    
    var body: some View {
        Group {
            if isLoading {
                Text("Loading...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: DS.s4) {
                    if let size = size {
                        Text("\(formatFileSize(size)) · ~\(formattedTokens)")
                            .font(.system(size: 13))
                    }
                    
                    if let lineCount = lineCount {
                        Text("\(lineCount) lines")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if size == nil && lineCount == nil {
                        Text("Unknown")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var formattedTokens: String {
        formatNumber(tokenEstimate ?? 0)
    }
}
