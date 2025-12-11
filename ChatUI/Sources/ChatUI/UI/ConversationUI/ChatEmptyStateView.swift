import SwiftUI
import UIConnections

struct ChatEmptyStateView: View {
    let selectedNode: FileNode?
    let onQuickAction: (String) -> Void
    
    var body: some View {
        Group {
            if let selectedNode {
                selectedNodeView(selectedNode)
            } else {
                noSelectionView
            }
        }
    }
    
    @ViewBuilder
    private func selectedNodeView(_ node: FileNode) -> some View {
        let isFolder = node.children != nil && !(node.children?.isEmpty ?? true)
        if isFolder {
            folderView(node)
        } else {
            fileView
        }
    }
    
    private var fileView: some View {
        VStack(spacing: DS.s16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No chat yet for this file")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            Text("Start by asking something about this file")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            quickActions([
                "Summarize this file",
                "List risky areas in this file",
                "Explain the main logic in this file"
            ])
        }
    }
    
    private func folderView(_ node: FileNode) -> some View {
        VStack(spacing: DS.s16) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Start chatting about this folder")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            if let children = node.children, !children.isEmpty {
                let files = children.filter { $0.children == nil || $0.children?.isEmpty == true }
                Text("\(children.count) items (\(files.count) files)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            quickActions([
                "Summarize this folder",
                "List key files in this folder",
                "Identify risks in this folder"
            ])
        }
    }
    
    private var noSelectionView: some View {
        VStack(spacing: DS.s16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select a file or folder to begin chatting")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
    }
    
    private func quickActions(_ prompts: [String]) -> some View {
        HStack(spacing: DS.s12) {
            ForEach(prompts.prefix(3), id: \.self) { prompt in
                Button(prompt) {
                    onQuickAction(prompt)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, DS.s8)
    }
}
