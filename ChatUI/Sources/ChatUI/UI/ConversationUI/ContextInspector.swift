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
import UIConnections
import Combine

enum InspectorTab: Int, CaseIterable {
    case files
    case quickHelp
    case context
    
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
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @EnvironmentObject var contextPresentationViewModel: ContextPresentationViewModel
    @StateObject private var metadataViewModel = FileMetadataViewModel()
    @StateObject private var filePreviewViewModel = FilePreviewViewModel()
    @StateObject private var fileStatsViewModel: FileStatsViewModel
    @StateObject private var folderStatsViewModel: FolderStatsViewModel
    @Binding var selectedInspectorTab: InspectorTab
    @State private var currentFileURL: URL?
    @State private var currentFolderURL: URL?
    
    init(selectedInspectorTab: Binding<InspectorTab>) {
        self._selectedInspectorTab = selectedInspectorTab
        let metadataVM = FileMetadataViewModel()
        _metadataViewModel = StateObject(wrappedValue: metadataVM)
        _fileStatsViewModel = StateObject(wrappedValue: FileStatsViewModel(metadataViewModel: metadataVM))
        _folderStatsViewModel = StateObject(wrappedValue: FolderStatsViewModel(metadataViewModel: metadataVM))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ContextInspectorTabs(selectedInspectorTab: $selectedInspectorTab)
                .overlay(Divider(), alignment: .bottom)
            tabContent
        }
        .frame(minWidth: 220, maxWidth: 300)
        .background(Color.clear)
        .overlay(alignment: .top) {
            if let message = contextPresentationViewModel.bannerMessage {
                ContextErrorBanner(message: message) {
                    withAnimation { contextPresentationViewModel.clearBanner() }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.horizontal, DS.s8)
                .padding(.top, DS.s8)
            }
        }
        .onChange(of: workspaceViewModel.lastContextResult) { _, newValue in
            if newValue != nil {
                contextPresentationViewModel.clearBanner()
            }
        }
        .onChange(of: workspaceViewModel.selectedNode?.path) { _, newURL in
            handleSelectionChange(newURL)
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedInspectorTab {
        case .files:
            filesTab
        case .context:
            ContextInspectorView()
                .environmentObject(workspaceViewModel)
        case .quickHelp:
            quickHelpTab
        }
    }
    
    private var filesTab: some View {
        Group {
            if let node = workspaceViewModel.selectedNode {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.s12) {
                        if let diagnostics = workspaceViewModel.lastContextResult {
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
                    .frame(maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Text(FileTypeClassifier.description(for: node.path))
            }
            PropertyRow(label: "Size") {
                AsyncFileStatsRowView(
                    url: node.path,
                    viewModel: fileStatsViewModel,
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
            AsyncFilePreviewView(url: node.path, viewModel: filePreviewViewModel)
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
                url: node.path,
                viewModel: folderStatsViewModel,
                formatFileSize: formatFileSize,
                formatNumber: formatNumber
            )
        }
    }
    
    private func inclusionBinding(for url: URL) -> Binding<Bool> {
        Binding(
            get: { workspaceViewModel.isPathIncludedInContext(url) },
            set: { include in workspaceViewModel.setContextInclusion(include, for: url) }
        )
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
    
    private func handleSelectionChange(_ newURL: URL?) {
        guard let url = newURL else {
            filePreviewViewModel.clear()
            fileStatsViewModel.clear()
            folderStatsViewModel.clear()
            currentFileURL = nil
            currentFolderURL = nil
            return
        }
        
        if workspaceViewModel.selectedNode?.isDirectory == true {
            if currentFolderURL != url {
                currentFolderURL = url
                // Trigger async load - this is explicit, not auto-triggered
                Task {
                    await folderStatsViewModel.loadStats(for: url)
                }
            }
        } else {
            if currentFileURL != url {
                currentFileURL = url
                // Trigger async load - this is explicit, not auto-triggered
                Task {
                    await filePreviewViewModel.loadPreview(for: url)
                    await fileStatsViewModel.loadStats(for: url)
                }
            }
        }
    }
}
