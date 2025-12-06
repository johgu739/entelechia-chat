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
import UniformTypeIdentifiers

struct FilesSidebarView: View {
    @ObservedObject var fileViewModel: FileViewModel
    @State private var isFileImporterPresented = false
    @State private var previewFile: LoadedFile?
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
            
            ContextBudgetSummaryView(
                includedCount: fileViewModel.includedFiles.count,
                includedBytes: fileViewModel.includedByteCount,
                includedTokens: fileViewModel.includedTokenCount,
                budget: fileViewModel.budget,
                byteFormatter: byteFormatter,
                tokenFormatter: tokenFormatter
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
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
                    }
                }
            }
        case .failure(let error):
            fileViewModel.errorMessage = "File selection failed: \(error.localizedDescription)"
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
    let byteFormatter: ByteCountFormatter
    let tokenFormatter: NumberFormatter
    let onPreview: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    
                    Text("\(byteFormatter.string(fromByteCount: Int64(file.byteCount))) · ~\(formattedTokens) tokens")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if let note = file.contextNote {
                        Text(note)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    if let reason = file.exclusionReason {
                        Label(reasonMessage(for: reason), systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
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
            .help("Include in Codex context (limits enforced automatically)")
            
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
    
    private var formattedTokens: String {
        tokenFormatter.string(from: NSNumber(value: file.tokenEstimate)) ?? "\(file.tokenEstimate)"
    }
    
    private func reasonMessage(for reason: ContextExclusionReason) -> String {
        switch reason {
        case .exceedsPerFileBytes(let limit):
            return "Trimmed: over \(byteFormatter.string(fromByteCount: Int64(limit)))"
        case .exceedsPerFileTokens(let limit):
            return "Trimmed: over ~\(limit) tokens"
        case .exceedsTotalBytes(let limit):
            return "Excluded: request already at \(byteFormatter.string(fromByteCount: Int64(limit)))"
        case .exceedsTotalTokens(let limit):
            return "Excluded: request already at ~\(limit) tokens"
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

private struct ContextBudgetSummaryView: View {
    let includedCount: Int
    let includedBytes: Int
    let includedTokens: Int
    let budget: ContextBudget
    let byteFormatter: ByteCountFormatter
    let tokenFormatter: NumberFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(includedCount) file\(includedCount == 1 ? "" : "s") included")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
            }
            
            BudgetRow(
                label: "Bytes",
                value: includedBytes,
                limit: budget.maxTotalBytes,
                formattedValue: byteFormatter.string(fromByteCount: Int64(includedBytes)),
                formattedLimit: byteFormatter.string(fromByteCount: Int64(budget.maxTotalBytes))
            )
            
            BudgetRow(
                label: "Tokens",
                value: includedTokens,
                limit: budget.maxTotalTokens,
                formattedValue: "~\(formatTokens(includedTokens))",
                formattedLimit: "~\(formatTokens(budget.maxTotalTokens))"
            )
        }
    }
    
    private func formatTokens(_ value: Int) -> String {
        tokenFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct BudgetRow: View {
    let label: String
    let value: Int
    let limit: Int
    let formattedValue: String
    let formattedLimit: String
    
    private var progressColor: Color {
        guard limit > 0 else { return .accentColor }
        let ratio = Double(value) / Double(limit)
        if ratio >= 1 {
            return .red
        } else if ratio >= 0.85 {
            return .orange
        } else {
            return .accentColor
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formattedValue) / \(formattedLimit)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(progressColor)
            }
            ProgressView(value: Double(min(value, limit)), total: Double(limit))
                .tint(progressColor)
        }
    }
}
