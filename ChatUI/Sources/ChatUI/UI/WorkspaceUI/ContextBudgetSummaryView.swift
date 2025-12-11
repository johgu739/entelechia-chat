import SwiftUI
import UIConnections

struct ContextBudgetSummaryView: View {
    let includedCount: Int
    let includedBytes: Int
    let includedTokens: Int
    let budget: ContextBudget
    let byteFormatter: ByteCountFormatter
    let tokenFormatter: NumberFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            HStack {
                Text("\(includedCount) file\(includedCount == 1 ? "" : "s") included")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
            }
            
            BudgetRow(
                label: "Bytes",
                value: includedBytes,
                limit: budget.maxTotalBytes,
                formattedValue: byteFormatter.string(fromByteCount: Int64(includedBytes)),
                formattedLimit: byteFormatter.string(fromByteCount: Int64(budget.maxTotalBytes))
            )
            
            BudgetRow(
                label: "Tokens",
                value: includedTokens,
                limit: budget.maxTotalTokens,
                formattedValue: "~\(formatTokens(includedTokens))",
                formattedLimit: "~\(formatTokens(budget.maxTotalTokens))"
            )
        }
    }
    
    private func formatTokens(_ value: Int) -> String {
        tokenFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
