import SwiftUI
import UIConnections

struct ContextPopoverView: View {
    let context: ContextBuildResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.s10) {
            Text("Context Sent to Codex")
                .font(.system(size: 14, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: DS.s8) {
                    ForEach(context.attachments, id: \.id) { file in
                        attachmentRow(file)
                    }
                    
                    if !context.truncatedFiles.isEmpty {
                        Divider()
                        Text("Truncated")
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(context.truncatedFiles, id: \.id) { file in
                            let byteCount = ByteCountFormatter.string(
                                fromByteCount: Int64(file.byteCount),
                                countStyle: .binary
                            )
                            Text("\(file.url.lastPathComponent) trimmed to \(byteCount)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !context.excludedFiles.isEmpty {
                        Divider()
                        Text("Excluded")
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(context.excludedFiles, id: \.id) { exclusion in
                            Text(verbatim: "\(exclusion.file.url.lastPathComponent) – \(exclusion.reason)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func attachmentRow(_ file: LoadedFile) -> some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            Text(file.url.lastPathComponent)
                .font(.system(size: 13, weight: .semibold))
            Text(file.url.path)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            HStack(spacing: DS.s8) {
                Text(ByteCountFormatter.string(fromByteCount: Int64(file.byteCount), countStyle: .binary))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                if let note = file.contextNote {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(DS.s8)
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}
