import SwiftUI
import UIConnections

struct AsyncFilePreviewView: View {
    let url: URL
    @ObservedObject var viewModel: FilePreviewViewModel
    
    var body: some View {
        InspectorSection(title: "PREVIEW") {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxHeight: 200)
            } else if let content = viewModel.content {
                ScrollView {
                    Text(content)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(20)
                }
                .frame(maxHeight: 200)
            } else {
                Text(viewModel.error?.localizedDescription ?? "Could not load content")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}
