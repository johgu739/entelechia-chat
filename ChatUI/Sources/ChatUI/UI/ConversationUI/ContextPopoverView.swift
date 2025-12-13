import SwiftUI
import UIContracts

struct ContextPopoverView: View {
    let context: UIContracts.UIContextBuildResult
    
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
                            let fileURL = URL(fileURLWithPath: file.path)
                            let byteCount = ByteCountFormatter.string(
                                fromByteCount: Int64(file.size),
                                countStyle: .binary
                            )
                            Text("\(fileURL.lastPathComponent) trimmed to \(byteCount)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !context.excludedFiles.isEmpty {
                        Divider()
                        Text("Excluded")
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(context.excludedFiles, id: \.id) { exclusion in
                            let fileURL = URL(fileURLWithPath: exclusion.file.path)
                            return Text(verbatim: "\(fileURL.lastPathComponent) – \(exclusion.reason)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func attachmentRow(_ file: UIContracts.UILoadedFile) -> some View {
        let fileURL = URL(fileURLWithPath: file.path)
        return VStack(alignment: .leading, spacing: DS.s4) {
            Text(fileURL.lastPathComponent)
                .font(.system(size: 13, weight: .semibold))
            Text(file.path)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            HStack(spacing: DS.s8) {
                Text(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .binary))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(DS.s8)
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}
