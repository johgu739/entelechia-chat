import SwiftUI
import UIConnections

enum ContextBarMetricsDisplay {
    case summary
    case detail(isCollapsed: Binding<Bool>)
}

struct ContextBarMetrics: View {
    let snapshot: ContextSnapshot?
    let display: ContextBarMetricsDisplay
    
    var body: some View {
        switch display {
        case .summary:
            summaryRow
        case .detail(let isCollapsed):
            detailSection(isCollapsed: isCollapsed)
        }
    }
    
    @ViewBuilder
    private var summaryRow: some View {
        if let snapshot {
            HStack(spacing: DS.s12) {
                metric("Files", "\(snapshot.includedFiles.count)")
                metric("Tokens", "\(snapshot.totalTokens)")
                metric("Segments", "\(snapshot.segments.count)")
            }
        } else {
            Text("No context yet")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func detailSection(isCollapsed: Binding<Bool>) -> some View {
        if let snapshot, !isCollapsed.wrappedValue {
            Divider()
            HStack(spacing: DS.s12) {
                detailItem("Segments", "\(snapshot.segments.count)")
                detailItem("Files", "\(snapshot.includedFiles.count)")
                detailItem("Tokens", "\(snapshot.totalTokens)")
                detailItem(
                    "Bytes",
                    ByteCountFormatter.string(
                        fromByteCount: Int64(snapshot.totalBytes),
                        countStyle: .binary
                    )
                )
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.s16)
            .padding(.vertical, DS.s8)
            .accessibilityElement(children: .combine)
        }
    }
    
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            Text(title)
                .font(DS.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
    }
    
    private func detailItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            Text(title)
                .font(DS.caption2)
                .foregroundColor(.secondary)
            Text(value)
        }
    }
}
