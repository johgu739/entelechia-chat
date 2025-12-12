import SwiftUI

struct AsyncFilePreviewView: View {
    let content: String?
    let isLoading: Bool
    let error: Error?
    
    var body: some View {
        InspectorSection(title: "PREVIEW") {
            if isLoading {
                ProgressView()
                    .frame(maxHeight: 200)
            } else if let content = content {
                ScrollView {
                    Text(content)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(20)
                }
                .frame(maxHeight: 200)
            } else {
                Text(error?.localizedDescription ?? "Could not load content")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}
