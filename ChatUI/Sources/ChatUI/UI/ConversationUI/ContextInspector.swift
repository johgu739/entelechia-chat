// @EntelechiaHeaderStart
// Signifier: ContextInspector
// Substance: Context inspector UI
// Genus: UI inspector
// Differentia: Shows file context metadata
// Form: Metadata display rules
// Matter: FileNode metadata; counts
// Powers: Show context info for selection
// FinalCause: Keep user aware of file context
// Relations: Serves workspace UI; depends on WorkspaceViewModel
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppKit
import UIContracts

// Use UIContracts.InspectorTab instead of local enum
typealias InspectorTab = UIContracts.InspectorTab

// Helper extension for UI-specific properties
extension UIContracts.InspectorTab {
    var title: String {
        switch self {
        case .files: return "Files"
        case .quickHelp: return "Quick Help"
        case .context: return "Context"
        }
    }
    
    var iconName: String {
        switch self {
        case .files: return "doc"
        case .quickHelp: return "questionmark.circle"
        case .context: return "square.stack.3d.up"
        }
    }
}

struct ContextInspector: View {
    let workspaceState: UIContracts.WorkspaceUIViewState
    let contextState: UIContracts.ContextViewState
    let filePreviewState: (content: String?, isLoading: Bool, error: Error?)
    let fileStatsState: (size: Int64?, lineCount: Int?, tokenEstimate: Int?, isLoading: Bool)
    let folderStatsState: (stats: UIContracts.FolderStats?, isLoading: Bool)
    @Binding var selectedInspectorTab: InspectorTab
    let onWorkspaceIntent: (UIContracts.WorkspaceIntent) -> Void
    let isPathIncludedInContext: (URL) -> Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if let message = contextState.bannerMessage {
                ContextErrorBanner(message: message) {
                    withAnimation { onWorkspaceIntent(.clearBanner) }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.horizontal, DS.s8)
                .padding(.top, DS.s8)
            }
            ContextInspectorTabs(selectedInspectorTab: $selectedInspectorTab)
                .overlay(Divider(), alignment: .bottom)
            tabContent
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active))
        .onChange(of: workspaceState.selectedNode?.path) { _, newURL in
            if let url = newURL {
                onWorkspaceIntent(.loadFilePreview(url))
                onWorkspaceIntent(.loadFileStats(url))
                if workspaceState.selectedNode?.isDirectory == true {
                    onWorkspaceIntent(.loadFolderStats(url))
                }
            } else {
                onWorkspaceIntent(.clearFilePreview)
                onWorkspaceIntent(.clearFileStats)
                onWorkspaceIntent(.clearFolderStats)
            }
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedInspectorTab {
        case .files:
            filesTab
        case .context:
            ContextInspectorView(snapshot: contextState.lastContextSnapshot)
        case .quickHelp:
            quickHelpTab
        }
    }
    
    private var filesTab: some View {
        Group {
            if let node = workspaceState.selectedNode {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.s12) {
                        if let diagnostics = contextState.lastContextResult {
                            ContextBudgetDiagnosticsView(
                                diagnostics: diagnostics,
                                formatFileSize: formatFileSize,
                                formatNumber: formatNumber
                            )
                            InspectorDivider()
                        }
                        if node.isDirectory {
                            folderMetadata(for: node)
                        } else {
                            fileMetadata(for: node)
                        }
                    }
                    .padding(DS.s12)
                }
            } else {
                emptySelection
            }
        }
    }
    
    private var quickHelpTab: some View {
        VStack(spacing: DS.s8) {
            Image(systemName: InspectorTab.quickHelp.iconName)
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Quick Help will appear here.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private var emptySelection: some View {
        VStack(spacing: DS.s12) {
            Image(systemName: InspectorTab.files.iconName)
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No file selected")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func fileMetadata(for node: FileNode) -> some View {
        InspectorSection(title: "IDENTITY & TYPE") {
            PropertyRow(label: "Path") {
                Text(node.path.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            PropertyRow(label: "Type") {
                Text(fileTypeDescription(for: node.path))
            }
            PropertyRow(label: "Size") {
                AsyncFileStatsRowView(
                    size: fileStatsState.size,
                    lineCount: fileStatsState.lineCount,
                    tokenEstimate: fileStatsState.tokenEstimate,
                    isLoading: fileStatsState.isLoading,
                    formatFileSize: formatFileSize,
                    formatNumber: formatNumber
                )
            }
        }
        InspectorDivider()
        InspectorSection(title: "CONTEXT") {
            Toggle(isOn: inclusionBinding(for: node.path)) {
                VStack(alignment: .leading, spacing: DS.s4) {
                    Text("Include in Codex context")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Persists in .entelechia/context_preferences.json")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
        InspectorDivider()
        InspectorSection(title: "CONTENT") {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([node.path])
            } label: {
                HStack(spacing: DS.s4) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 11))
                    Text("Reveal in Finder")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, DS.s4)
            AsyncFilePreviewView(
                content: filePreviewState.content,
                isLoading: filePreviewState.isLoading,
                error: filePreviewState.error
            )
        }
    }
    
    @ViewBuilder
    private func folderMetadata(for node: FileNode) -> some View {
        InspectorSection(title: "IDENTITY") {
            PropertyRow(label: "Path") {
                Text(node.path.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        InspectorDivider()
        InspectorSection(title: "CONTEXT") {
            Toggle(isOn: Binding(
                get: { isPathIncludedInContext(node.path) },
                set: { onWorkspaceIntent(.setContextInclusion($0, node.path)) }
            )) {
                VStack(alignment: .leading, spacing: DS.s4) {
                    Text("Include in Codex context")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Persists in .entelechia/context_preferences.json")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
        InspectorDivider()
        InspectorSection(title: "CONTENTS") {
            let children = node.children ?? []
            let files = children.filter { $0.children == nil || $0.children?.isEmpty == true }
            let folders = children.filter { $0.children != nil && !($0.children?.isEmpty ?? true) }
            PropertyRow(label: "Items") {
                if !children.isEmpty {
                    Text("\(children.count) (\(files.count) files, \(folders.count) folders)")
                } else {
                    Text("Empty folder")
                        .foregroundColor(.secondary)
                }
            }
            AsyncFolderStatsView(
                stats: folderStatsState.stats,
                isLoading: folderStatsState.isLoading,
                formatFileSize: formatFileSize,
                formatNumber: formatNumber
            )
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    // MARK: - Helper Functions
    
    private func fileTypeDescription(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let sourceExtensions: Set<String> = [
            "swift", "m", "mm", "c", "cc", "cpp", "cxx", "h", "hpp", "hh",
            "java", "kt", "kts", "ts", "tsx", "js", "jsx", "go", "rs",
            "py", "rb", "php", "cs", "sql", "sh", "bash", "zsh", "fish"
        ]
        let textExtensions: Set<String> = [
            "txt", "md", "markdown", "rst", "json", "yaml", "yml", "toml",
            "xml", "plist", "csv", "log"
        ]
        
        if sourceExtensions.contains(ext) { return "Source Code" }
        if textExtensions.contains(ext) { return "Text" }
        if ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "svg"].contains(ext) { return "Image" }
        if ext == "pdf" { return "PDF" }
        return "File"
    }
    
    private func inclusionBinding(for url: URL) -> Binding<Bool> {
        Binding(
            get: { isPathIncludedInContext(url) },
            set: { onWorkspaceIntent(.setContextInclusion($0, url)) }
        )
    }
}
