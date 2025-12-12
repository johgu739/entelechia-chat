// @EntelechiaHeaderStart
// Signifier: FilesSidebarView
// Substance: Sidebar UI
// Genus: UI navigator
// Differentia: Displays file tree sidebar
// Form: Layout of file list and controls
// Matter: File nodes; selection bindings
// Powers: Present tree; handle selection
// FinalCause: Navigate project files
// Relations: Serves workspace UI
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppKit
import UIContracts

struct FileRowData: Identifiable {
    let id: UUID
    let fileName: String
    let byteCount: Int
    let tokenEstimate: Int
    let contextNote: String?
    let exclusionReason: UIContracts.ContextExclusionReasonView?
    let iconName: String
    let isIncludedInContext: Bool
}

struct FilesSidebarView: View {
    let files: [FileRowData]
    let includedCount: Int
    let includedBytes: Int
    let includedTokens: Int
    let budget: UIContracts.ContextBudgetView
    let errorMessage: String?
    @State private var isFileImporterPresented = false
    @State private var previewFileID: UUID?
    @State private var selectedFileID: UUID?
    
    let onAddFiles: () -> Void
    let onClearFiles: () -> Void
    let onDismissError: () -> Void
    let onFileSelected: (UUID) -> Void
    let onToggleFileInclusion: (UUID) -> Void
    let onPreviewFile: (UUID) -> Void
    let onDropFiles: ([URL]) -> Void
    
    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()
    
    private let tokenFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            FilesSidebarHeader(
                hasFiles: !files.isEmpty,
                onAdd: { isFileImporterPresented = true },
                onClear: onClearFiles
            )
            
            ContextBudgetSummaryView(
                includedCount: includedCount,
                includedBytes: includedBytes,
                includedTokens: includedTokens,
                budget: budget,
                byteFormatter: byteFormatter,
                tokenFormatter: tokenFormatter
            )
            .padding(.horizontal, DS.s12)
            .padding(.vertical, DS.s8)
            
            // Error message display
            if let errorMessage = errorMessage {
                FilesSidebarErrorView(
                    message: errorMessage,
                    onDismiss: onDismissError
                )
            }
            
            // Files list
            if files.isEmpty {
                FilesSidebarEmptyState(onDrop: handleDrop)
            } else {
                List(selection: $selectedFileID) {
                    ForEach(files) { file in
                        FileRow(
                            fileID: file.id,
                            fileName: file.fileName,
                            byteCount: file.byteCount,
                            tokenEstimate: file.tokenEstimate,
                            contextNote: file.contextNote,
                            exclusionReason: file.exclusionReason,
                            iconName: file.iconName,
                            isIncludedInContext: file.isIncludedInContext,
                            byteFormatter: byteFormatter,
                            tokenFormatter: tokenFormatter,
                            onToggleInclusion: { onToggleFileInclusion(file.id) },
                            onPreview: { onPreviewFile(file.id) }
                        )
                        .tag(file.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: DS.s20 * CGFloat(11), maxWidth: DS.s20 * CGFloat(15))
        .background(AppTheme.panelBackground)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                onDropFiles(urls)
            case .failure:
                break
            }
        }
        .sheet(item: Binding(
            get: { previewFileID.map { id in PreviewFileID(id: id) } },
            set: { previewFileID = $0?.id }
        )) { previewID in
            if let file = files.first(where: { $0.id == previewID.id }) {
                FilePreviewView(
                    fileName: file.fileName,
                    content: "", // Content would come from ViewState
                    isSourceCode: file.iconName.contains("code") || file.iconName.contains("swift")
                )
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileURLIdentifier = "public.file-url"
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(fileURLIdentifier) {
            provider.loadItem(forTypeIdentifier: fileURLIdentifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
            }
        }
        if !urls.isEmpty {
            onDropFiles(urls)
        }
        return true
    }
}

private struct PreviewFileID: Identifiable {
    let id: UUID
}
