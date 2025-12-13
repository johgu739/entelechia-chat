import SwiftUI
import UIContracts

struct FileRow: View {
    let fileID: UUID
    let fileName: String
    let byteCount: Int
    let tokenEstimate: Int
    let contextNote: String?
    let exclusionReason: UIContracts.ContextExclusionReasonView?
    let iconName: String
    let isIncludedInContext: Bool
    let byteFormatter: ByteCountFormatter
    let tokenFormatter: NumberFormatter
    let onToggleInclusion: () -> Void
    let onPreview: () -> Void
    
    var body: some View {
        HStack(spacing: DS.s6) {
            Label {
                VStack(alignment: .leading, spacing: DS.s4) {
                    Text(fileName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    
                    Text("\(byteFormatter.string(fromByteCount: Int64(byteCount))) · ~\(formattedTokens) tokens")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if let note = contextNote {
                        Text(note)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    if let reason = exclusionReason {
                        Label(reasonMessage(for: reason), systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.warningColor)
                    }
                }
            } icon: {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: DS.s12)
            }
            .labelStyle(.titleAndIcon)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isIncludedInContext },
                set: { _ in onToggleInclusion() }
            ))
            .toggleStyle(.checkbox)
            .help("Include in Codex context (limits enforced automatically)")
            
            Button(action: onPreview) {
                Image(systemName: "eye")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Preview")
        }
        .padding(.vertical, DS.s4)
        .padding(.horizontal, DS.s4)
        .contentShape(Rectangle())
        .onTapGesture {
            onPreview()
        }
    }
    
    private var formattedTokens: String {
        tokenFormatter.string(from: NSNumber(value: tokenEstimate)) ?? "\(tokenEstimate)"
    }
    
    private func reasonMessage(for reason: UIContracts.ContextExclusionReasonView) -> String {
        switch reason {
        case .exceedsPerFileBytes(let limit):
            return "Trimmed: over \(byteFormatter.string(fromByteCount: Int64(limit)))"
        case .exceedsPerFileTokens(let limit):
            return "Trimmed: over ~\(limit) tokens"
        case .exceedsTotalBytes(let limit):
            return "Excluded: request already at \(byteFormatter.string(fromByteCount: Int64(limit)))"
        case .exceedsTotalTokens(let limit):
            return "Excluded: request already at ~\(limit) tokens"
        }
    }
}
