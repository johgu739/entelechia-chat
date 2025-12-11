import SwiftUI
import UIConnections

struct ContextBudgetDiagnosticsView: View {
    let diagnostics: ContextBuildResult
    let formatFileSize: (Int64) -> String
    let formatNumber: (Int) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorSection(title: "CONTEXT BUDGET") {
                budgetRow(
                    label: "Bytes",
                    value: diagnostics.totalBytes,
                    limit: diagnostics.budget.maxTotalBytes,
                    formattedValue: formatFileSize(Int64(diagnostics.totalBytes)),
                    formattedLimit: formatFileSize(Int64(diagnostics.budget.maxTotalBytes))
                )
                
                budgetRow(
                    label: "Tokens",
                    value: diagnostics.totalTokens,
                    limit: diagnostics.budget.maxTotalTokens,
                    formattedValue: "~\(formatNumber(diagnostics.totalTokens))",
                    formattedLimit: "~\(formatNumber(diagnostics.budget.maxTotalTokens))"
                )
            }
            
            if !diagnostics.truncatedFiles.isEmpty {
                InspectorDivider()
                InspectorSection(title: "TRIMMED FILES") {
                    ForEach(diagnostics.truncatedFiles) { file in
                        VStack(alignment: .leading, spacing: DS.s4) {
                            Text(file.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text(file.contextNote ?? "Trimmed to respect per-file limits.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, DS.s4)
                    }
                }
            }
            
            if !diagnostics.excludedFiles.isEmpty {
                InspectorDivider()
                InspectorSection(title: "EXCLUDED FILES") {
                    ForEach(diagnostics.excludedFiles) { exclusion in
                        VStack(alignment: .leading, spacing: DS.s4) {
                            Text(exclusion.file.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text(exclusionMessage(for: exclusion.reason))
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, DS.s4)
                    }
                }
            }
        }
    }
    
    private func budgetRow(
        label: String,
        value: Int,
        limit: Int,
        formattedValue: String,
        formattedLimit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formattedValue) / \(formattedLimit)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(progressColor(value: value, limit: limit))
            }
            ProgressView(value: Double(min(value, limit)), total: Double(limit))
                .tint(progressColor(value: value, limit: limit))
        }
    }
    
    private func progressColor(value: Int, limit: Int) -> Color {
        let ratio = Double(value) / Double(limit)
        if ratio >= 1 {
            return .red
        } else if ratio >= 0.85 {
            return .orange
        } else {
            return .accentColor
        }
    }
    
    private func exclusionMessage(for reason: ContextExclusionReason) -> String {
        switch reason {
        case .exceedsPerFileBytes(let limit):
            return "Removed because it exceeded \(formatFileSize(Int64(limit)))."
        case .exceedsPerFileTokens(let limit):
            return "Removed because it exceeded ~\(formatNumber(limit)) tokens."
        case .exceedsTotalBytes(let limit):
            return "Skipped because total byte budget (\(formatFileSize(Int64(limit)))) was reached."
        case .exceedsTotalTokens(let limit):
            return "Skipped because total token budget (~\(formatNumber(limit))) was reached."
        }
    }
}
