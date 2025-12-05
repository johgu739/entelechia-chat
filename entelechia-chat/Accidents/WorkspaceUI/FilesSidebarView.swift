// @EntelechiaHeaderStart
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
import UniformTypeIdentifiers

struct FilesSidebarView: View {
    @ObservedObject var fileViewModel: FileViewModel
    @State private var isFileImporterPresented = false
    @State private var previewFile: LoadedFile?
    @State private var selectedFileID: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Inspector-header
            HStack {
                Text("Context Files")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    isFileImporterPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Add files")
                
                if !fileViewModel.loadedFiles.isEmpty {
                    Button {
                        fileViewModel.clearFiles()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .help("Clear all context files")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.windowBackground)
            .overlay(Divider(), alignment: .bottom)
            
            // Error message display
            if let errorMessage = fileViewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        fileViewModel.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .overlay(Divider(), alignment: .bottom)
            }
            
            // Files list
            if fileViewModel.loadedFiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No files attached")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Drag files here or click +")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                }
            } else {
                List(selection: $selectedFileID) {
                    ForEach(fileViewModel.loadedFiles) { file in
                        FileRow(file: file, fileViewModel: fileViewModel, onPreview: {
                            previewFile = file
                        })
                        .tag(file.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 220, maxWidth: 300)
        .background(AppTheme.panelBackground)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.text, .sourceCode, .data],
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
                        fileViewModel.errorMessage = "Failed to load \(url.lastPathComponent): \(error.localizedDescription)"
                        print("Failed to load file \(url.path): \(error)")
                    }
                }
            }
        case .failure(let error):
            fileViewModel.errorMessage = "File selection failed: \(error.localizedDescription)"
            print("File selection failed: \(error)")
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let error = error {
                        Task { @MainActor in
                            fileViewModel.errorMessage = "Failed to load dropped file: \(error.localizedDescription)"
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
                                    fileViewModel.errorMessage = "Failed to load \(url.lastPathComponent): \(error.localizedDescription)"
                                }
                                print("Failed to load dropped file \(url.path): \(error)")
                            }
                        }
                    }
                }
            }
        }
        return true
    }
}

struct FileRow: View {
    let file: LoadedFile
    @ObservedObject var fileViewModel: FileViewModel
    let onPreview: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    
                    Text("\(file.content.count) characters")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } icon: {
                Image(systemName: file.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
            }
            .labelStyle(.titleAndIcon)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { file.isIncludedInContext },
                set: { _ in fileViewModel.toggleFileInclusion(file) }
            ))
            .toggleStyle(.checkbox)
            .help("Include in context")
            
            Button(action: onPreview) {
                Image(systemName: "eye")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Preview")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onPreview()
        }
    }
}

struct FilePreviewView: View {
    let file: LoadedFile
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if file.fileType?.conforms(to: .sourceCode) == true || file.fileType?.conforms(to: .text) == true {
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
        .frame(minWidth: 600, minHeight: 400)
    }
}
