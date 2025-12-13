import SwiftUI
import UIContracts

struct ContextInspectorSegmentList: View {
    let segments: [UIContracts.ContextSegmentDescriptor]
    
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
            .background(.thinMaterial)
        }
    }
}

