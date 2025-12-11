import SwiftUI
import UIConnections

struct FilePreviewView: View {
    let file: WorkspaceLoadedFile
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if file.fileKind == .sourceCode || file.fileKind == .text {
                    Text(file.content)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    Text(file.content)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .navigationTitle(file.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: DS.s20 * CGFloat(30), minHeight: DS.s20 * CGFloat(20))
    }
}
