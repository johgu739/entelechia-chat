import SwiftUI
import UIConnections

struct ContextBarHeader: View {
    let activeScope: ContextScopeChoice
    let snapshotHash: String?
    let onViewDetails: () -> Void
    
    var body: some View {
        HStack(spacing: DS.s12) {
            VStack(alignment: .leading, spacing: DS.s4) {
                Text(activeScope.displayName)
                    .font(.system(size: 13, weight: .semibold))
                if let hash = snapshotHash {
                    Text("Snapshot \(hash.prefix(8))…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onViewDetails) {
                Text("View Details")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("View context details")
            .frame(minWidth: 44, minHeight: 32)
        }
    }
}

