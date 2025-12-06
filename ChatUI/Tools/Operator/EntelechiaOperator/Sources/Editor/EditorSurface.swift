// @EntelechiaHeaderStart
// Signifier: EditorSurface
// Substance: Operator editor surface
// Genus: UI container
// Differentia: Hosts code/markdown/terminal panes
// Form: Composite of editing/inspection panes
// Matter: Current document state; layout configuration
// Powers: Host editing/inspection panes coherently
// FinalCause: Provide unified editing environment for operator
// Relations: Serves operator workspace; coordinates subviews
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import Engine

struct EditorSurface: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            EditorTabBar(tabs: appState.openTabs, activeTabID: appState.activeTabID) { tab in
                appState.activeTabID = tab.id
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if let activeID = appState.activeTabID,
               let activeTab = appState.openTabs.first(where: { $0.id == activeID }) {
                UniversalEditor(content: activeTab.content)
            } else {
                PlaceholderEditor()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EditorTabBar: View {
    let tabs: [EditorTab]
    let activeTabID: UUID?
    let onSelect: (EditorTab) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs) { tab in
                    Button {
                        onSelect(tab)
                    } label: {
                        Text(tab.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(activeTabID == tab.id ? .primary : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(activeTabID == tab.id ? Color(nsColor: .controlAccentColor).opacity(0.15) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct UniversalEditor: View {
    let content: EditorTab.ContentType

    var body: some View {
        switch content {
        case .file(let url):
            CodeView(fileURL: url)
        case .chat(let id):
            OperatorChatView(sessionID: id)
        case .markdown(let markdown):
            MarkdownDocumentView(markdown: markdown)
        case .patch(let patchID):
            PatchDiffView(patchID: patchID)
        case .terminal(let stream):
            TerminalView(streamID: stream)
        }
    }
}

struct PlaceholderEditor: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.dashed")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Open a file, chat, or log stream to begin")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}