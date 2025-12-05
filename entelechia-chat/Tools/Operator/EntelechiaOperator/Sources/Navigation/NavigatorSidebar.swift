// @EntelechiaHeaderStart
// Signifier: NavigatorSidebar
// Substance: Operator navigator sidebar UI
// Genus: UI navigator
// Differentia: Renders navigable operator targets
// Form: Tree/list rendering of operator targets
// Matter: Navigation items; selection bindings
// Powers: Present items; handle selection
// FinalCause: Let operator choose contexts/tools
// Relations: Serves operator workspace; depends on app state
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI

struct NavigatorSidebar: View {
    @EnvironmentObject private var appState: AppState
    @State private var fileTree: [FileNode] = FileNode.mockTree

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NavigatorSection(title: "FILES", nodes: fileTree) { node in
                    appState.selection = .file(node.path)
                }
                NavigatorSection(title: "CODEX SESSIONS", nodes: []) { _ in }
                NavigatorSection(title: "DAEMONS", nodes: []) { _ in }
                NavigatorSection(title: "LOG STREAMS", nodes: []) { _ in }
                NavigatorSection(title: "ACTIVE PATCHES", nodes: []) { _ in }
            }
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

private struct NavigatorSection: View {
    let title: String
    let nodes: [FileNode]
    let onSelect: (FileNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.smallCaps())
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            if nodes.isEmpty {
                Text("No items yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else {
                OutlineGroup(nodes, children: \.children) { node in
                    Button {
                        onSelect(node)
                    } label: {
                        HStack {
                            Image(systemName: node.icon)
                            Text(node.name)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)
            }
        }
    }
}