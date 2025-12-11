import SwiftUI
import UIConnections

struct ContextInspectorFileRow: View {
    let file: ContextFileDescriptor
    let truncated: Bool
    let excluded: Bool
    
    init(file: ContextFileDescriptor, truncated: Bool = false, excluded: Bool = false) {
        self.file = file
        self.truncated = truncated
        self.excluded = excluded
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            Text(file.path)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(2)
                .truncationMode(.middle)
            HStack(spacing: DS.s6) {
                if let lang = file.language {
                    Text(lang)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Text(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .binary))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                if !file.hash.isEmpty {
                    Text("hash \(file.hash.prefix(8))…")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                if truncated {
                    Text("trimmed")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                }
                if excluded {
                    Text("excluded")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.red)
                }
            }
        }
    }
}
