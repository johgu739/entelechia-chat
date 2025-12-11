import SwiftUI
import UIConnections

struct FileRow: View {
    let file: WorkspaceLoadedFile
    @ObservedObject var fileViewModel: FileViewModel
    let byteFormatter: ByteCountFormatter
    let tokenFormatter: NumberFormatter
    let onPreview: () -> Void
    
    var body: some View {
        HStack(spacing: DS.s6) {
            Label {
                VStack(alignment: .leading, spacing: DS.s4) {
                    Text(file.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    
                    Text("\(byteFormatter.string(fromByteCount: Int64(file.byteCount))) · ~\(formattedTokens) tokens")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if let note = file.contextNote {
                        Text(note)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    if let reason = file.exclusionReason {
                        Label(reasonMessage(for: reason), systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                }
            } icon: {
                Image(systemName: file.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: DS.s12)
            }
            .labelStyle(.titleAndIcon)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { file.isIncludedInContext },
                set: { _ in fileViewModel.toggleFileInclusion(file) }
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
        tokenFormatter.string(from: NSNumber(value: file.tokenEstimate)) ?? "\(file.tokenEstimate)"
    }
    
    private func reasonMessage(for reason: ContextExclusionReason) -> String {
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
