import SwiftUI
import UIConnections

struct ContextBar: View {
    var snapshot: ContextSnapshot?
    var activeScope: ContextScopeChoice
    var onViewDetails: () -> Void
    
    @State private var isCollapsed = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerRow
            ContextBarMetrics(
                snapshot: snapshot,
                display: .detail(isCollapsed: $isCollapsed)
            )
        }
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(DS.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r12)
                        .stroke(DS.stroke, lineWidth: 1)
                )
        )
        .padding(.horizontal, DS.s16)
    }
    
    private var headerRow: some View {
        HStack(spacing: DS.s12) {
            ContextBarChevron(isCollapsed: $isCollapsed)
            ContextBarHeader(
                activeScope: activeScope,
                snapshotHash: snapshot?.snapshotHash,
                onViewDetails: onViewDetails
            )
            ContextBarMetrics(
                snapshot: snapshot,
                display: .summary
            )
        }
        .padding(.horizontal, DS.s16)
        .padding(.vertical, DS.s10)
        .accessibilityElement(children: .combine)
    }
}
