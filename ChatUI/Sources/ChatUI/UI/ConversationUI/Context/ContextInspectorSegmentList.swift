import SwiftUI
import UIConnections

struct ContextInspectorSegmentList: View {
    let segments: [ContextSegmentDescriptor]
    
    var body: some View {
        ForEach(segments) { segment in
            VStack(alignment: .leading, spacing: DS.s4) {
                Text("Tokens: \(segment.totalTokens)  Bytes: \(segment.totalBytes)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                ForEach(segment.files) { file in
                    ContextInspectorFileRow(file: file)
                }
            }
            .padding(DS.s8)
            .background(RoundedRectangle(cornerRadius: DS.r12).fill(Color.secondary.opacity(0.08)))
        }
    }
}

