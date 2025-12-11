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
import UIConnections

struct FilesSidebarView: View {
    @ObservedObject var fileViewModel: FileViewModel
    @State private var isFileImporterPresented = false
    @State private var previewFile: WorkspaceLoadedFile?
    @State private var selectedFileID: UUID?
    
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
                hasFiles: !fileViewModel.loadedFiles.isEmpty,
                onAdd: { isFileImporterPresented = true },
                onClear: { fileViewModel.clearFiles() }
            )
            
            ContextBudgetSummaryView(
                includedCount: fileViewModel.includedFiles.count,
                includedBytes: fileViewModel.includedByteCount,
                includedTokens: fileViewModel.includedTokenCount,
                budget: fileViewModel.budget,
                byteFormatter: byteFormatter,
                tokenFormatter: tokenFormatter
            )
            .padding(.horizontal, DS.s12)
            .padding(.vertical, DS.s8)
            
            // Error message display
            if let errorMessage = fileViewModel.errorMessage {
                FilesSidebarErrorView(
                    message: errorMessage,
                    onDismiss: { fileViewModel.errorMessage = nil }
                )
            }
            
            // Files list
            if fileViewModel.loadedFiles.isEmpty {
                FilesSidebarEmptyState(onDrop: handleDrop)
            } else {
                List(selection: $selectedFileID) {
                    ForEach(fileViewModel.loadedFiles) { file in
                        FileRow(
                            file: file,
                            fileViewModel: fileViewModel,
                            byteFormatter: byteFormatter,
                            tokenFormatter: tokenFormatter,
                            onPreview: {
                            previewFile = file
                        })
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
            handleFileSelection(result: result)
        }
        .sheet(item: $previewFile) { file in
            FilePreviewView(file: file)
        }
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls {
                    do {
                        try await fileViewModel.loadFile(from: url)
                    } catch {
                        // Show user-friendly error
                        fileViewModel.errorMessage = "Failed to load \(url.lastPathComponent): " +
                            "\(error.localizedDescription)"
                    }
                }
            }
        case .failure(let error):
            fileViewModel.errorMessage = "File selection failed: \(error.localizedDescription)"
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileURLIdentifier = "public.file-url"
        for provider in providers where provider.hasItemConformingToTypeIdentifier(fileURLIdentifier) {
            provider.loadItem(forTypeIdentifier: fileURLIdentifier, options: nil) { item, error in
                if let error = error {
                    Task { @MainActor in
                        let message = "Failed to load dropped file: \(error.localizedDescription)"
                        fileViewModel.errorMessage = message
                    }
                    return
                }
                
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    Task {
                        do {
                            try await fileViewModel.loadFile(from: url)
                        } catch {
                            await MainActor.run {
                                let message = "Failed to load \(url.lastPathComponent): \(error.localizedDescription)"
                                fileViewModel.errorMessage = message
                            }
                        }
                    }
                }
            }
        }
        return true
    }
}
