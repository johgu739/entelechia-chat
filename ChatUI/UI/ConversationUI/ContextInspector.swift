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
import UniformTypeIdentifiers
import CoreEngine
import Combine

struct ContextInspector: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @StateObject private var metadataViewModel = FileMetadataViewModel()
    @State private var selectedInspectorTab: InspectorTab = .file
    @State private var contextErrorBanner: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Xcode-liknande inspector-tabs (File / History / Quick Help)
            HStack {
                Picker("", selection: $selectedInspectorTab) {
                    ForEach(InspectorTab.allCases, id: \.self) { tab in
                        Image(systemName: tab.iconName)
                            .help(tab.accessibilityLabel)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 140)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.clear)
            .overlay(Divider(), alignment: .bottom)
            
            // Content per tab
            Group {
                switch selectedInspectorTab {
                case .file:
                    if let node = workspaceViewModel.selectedNode {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                if let diagnostics = workspaceViewModel.lastContextResult {
                                    ContextBudgetDiagnosticsView(
                                        diagnostics: diagnostics,
                                        formatFileSize: formatFileSize,
                                        formatNumber: formatNumber
                                    )
                                    InspectorDivider()
                                }
                                // Bestäm fil vs mapp utifrån `isDirectory`.
                                if node.isDirectory {
                                    folderMetadata(for: node)
                                } else {
                                    fileMetadata(for: node)
                                }
                            }
                            .padding(12)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("No file selected")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    
                case .history:
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("History inspector is coming soon.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .quickHelp:
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("Quick Help will appear here.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 220, maxWidth: 300)
        .background(Color.clear)
        .overlay(alignment: .top) {
            if let message = contextErrorBanner {
                ContextErrorBanner(message: message) {
                    withAnimation { contextErrorBanner = nil }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }
        }
        .onChange(of: workspaceViewModel.lastContextResult) { _, newValue in
            if newValue != nil {
                contextErrorBanner = nil
            }
        }
        .onReceive(workspaceViewModel.contextErrorPublisher) { message in
            withAnimation {
                contextErrorBanner = message
            }
        }
    }

    // MARK: - Tabs
    
    private enum InspectorTab: Int, CaseIterable {
        case file
        case history
        case quickHelp
        
        var iconName: String {
            switch self {
            case .file: return "doc"
            case .history: return "clock.arrow.circlepath"
            case .quickHelp: return "questionmark.circle"
            }
        }
        
        var accessibilityLabel: String {
            switch self {
            case .file: return "File Inspector"
            case .history: return "History"
            case .quickHelp: return "Quick Help"
            }
        }
    }
    
    @ViewBuilder
    private func fileMetadata(for node: FileNode) -> some View {
        // Xcode-liknande layout: radbaserad metadata.
        InspectorSection(title: "IDENTITY & TYPE") {
            PropertyRow(label: "Path") {
                Text(node.path.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            if let fileType = UTType(filenameExtension: node.path.pathExtension) {
                PropertyRow(label: "Type") {
                    Text(fileType.localizedDescription ?? fileType.identifier)
                }
            }
            PropertyRow(label: "Size") {
                AsyncFileStatsRowView(
                    url: node.path,
                    metadataViewModel: metadataViewModel,
                    formatFileSize: formatFileSize,
                    formatNumber: formatNumber
                )
            }
        }
        
        InspectorDivider()
        
        InspectorSection(title: "CONTEXT") {
            Toggle(isOn: inclusionBinding(for: node.path)) {
                VStack(alignment: .leading, spacing: 2) {
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
            // Open in Finder + preview som underinnehåll
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([node.path])
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 11))
                    Text("Reveal in Finder")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
            
            AsyncFilePreviewView(url: node.path)
        }
    }
    
    @ViewBuilder
    private func folderMetadata(for node: FileNode) -> some View {
        // Identity
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
                VStack(alignment: .leading, spacing: 2) {
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
        
        // Contents
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
                metadataViewModel: metadataViewModel,
                formatFileSize: formatFileSize,
                formatNumber: formatNumber
            )
        }
    }
    
    private func inclusionBinding(for url: URL) -> Binding<Bool> {
        Binding(
            get: { workspaceViewModel.isPathIncludedInContext(url) },
            set: { include in
                workspaceViewModel.setContextInclusion(include, for: url)
            }
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
}

private struct ContextErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(3)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.9))
                .shadow(radius: 4)
        )
    }
}

// MARK: - Inspector Section

private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
            
            content
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Inspector Divider

private struct InspectorDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 4)
    }
}

// MARK: - Property Row (Xcode-like)

private struct PropertyRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            
            content
                .font(.system(size: 13))
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Async Metadata Views

private struct AsyncLineCountView: View {
    let url: URL
    @ObservedObject var metadataViewModel: FileMetadataViewModel
    @State private var lineCount: Int?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                InspectorSection(title: "LINES") {
                    Text("Loading...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            } else if let lineCount = lineCount {
                InspectorSection(title: "LINES") {
                    Text("\(lineCount) lines")
                        .font(.system(size: 13))
                }
            }
        }
        .task(id: url) {
            isLoading = true
            lineCount = await metadataViewModel.lineCount(for: url)
            isLoading = false
        }
    }
}

private struct AsyncFileStatsRowView: View {
    let url: URL
    @ObservedObject var metadataViewModel: FileMetadataViewModel
    let formatFileSize: (Int64) -> String
    let formatNumber: (Int) -> String
    @State private var size: Int64?
    @State private var lineCount: Int?
    @State private var tokenEstimate: Int?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                Text("Loading...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    if let size = size {
                        Text("\(formatFileSize(size)) · ~\(formatTokens(tokenEstimate)) tokens")
                            .font(.system(size: 13))
                    }

                    if let lineCount = lineCount {
                        Text("\(lineCount) lines")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    if size == nil && lineCount == nil {
                        Text("Unknown")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task(id: url) {
            isLoading = true
            size = nil
            lineCount = nil
            tokenEstimate = nil
            do {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                size = resourceValues.fileSize.map(Int64.init)
                if let fileSize = resourceValues.fileSize {
                    tokenEstimate = TokenEstimator.estimateTokens(forByteCount: fileSize)
                }
            } catch {
                print("Failed to get file size: \(error.localizedDescription)")
            }
            lineCount = await metadataViewModel.lineCount(for: url)
            isLoading = false
        }
    }
    
    private func formatTokens(_ tokens: Int?) -> String {
        guard let tokens else { return "0" }
        return formatNumber(tokens)
    }
}

private struct AsyncFolderStatsView: View {
    let url: URL
    @ObservedObject var metadataViewModel: FileMetadataViewModel
    let formatFileSize: (Int64) -> String
    let formatNumber: (Int) -> String
    @State private var stats: FileMetadataViewModel.FolderStats?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                InspectorSection(title: "TOTAL SIZE") {
                    Text("Loading...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            } else if let stats = stats {
                InspectorSection(title: "TOTAL SIZE") {
                    Text(formatFileSize(stats.totalSize))
                        .font(.system(size: 13))
                }
                
                InspectorSection(title: "TOKENS") {
                    Text("~\(formatNumber(stats.totalTokens)) tokens")
                        .font(.system(size: 13))
                }
                
                if stats.totalLines > 0 {
                    InspectorSection(title: "TOTAL LINES") {
                        Text("~\(formatNumber(stats.totalLines)) lines of code")
                            .font(.system(size: 13))
                    }
                }
            }
        }
        .task(id: url) {
            isLoading = true
            stats = await metadataViewModel.folderStats(for: url)
            isLoading = false
        }
    }
}

private struct AsyncFileSizeView: View {
    let url: URL
    let formatFileSize: (Int64) -> String
    @State private var size: Int64?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                Text("Loading...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else if let size = size {
                Text(formatFileSize(size))
                    .font(.system(size: 13))
            } else {
                Text("Unknown")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .task(id: url) {
            isLoading = true
            do {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                size = resourceValues.fileSize.map(Int64.init)
            } catch {
                print("Failed to get file size: \(error.localizedDescription)")
                size = nil
            }
            isLoading = false
        }
    }
}

private struct AsyncFilePreviewView: View {
    let url: URL
    @State private var content: String?
    @State private var isLoading = true
    @State private var error: Error?
    
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
        .task(id: url) {
            isLoading = true
            error = nil
            content = nil
            do {
                // Check if file is text-based
                let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
                guard let contentType = resourceValues.contentType,
                      contentType.conforms(to: .text) || contentType.conforms(to: .sourceCode) else {
                    error = FilePreviewError.notATextFile
                    isLoading = false
                    return
                }
                
                // Load content async
                let loadTask = Task(priority: .utility) {
                    if let data = try? Data(contentsOf: url),
                       let text = String(data: data, encoding: .utf8) {
                        // Limit preview to first 1000 lines
                        let lines = text.components(separatedBy: .newlines)
                        return lines.prefix(1000).joined(separator: "\n")
                    }
                    return try String(contentsOf: url, encoding: .utf8)
                }
                content = try await loadTask.value
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
    
    enum FilePreviewError: LocalizedError {
        case notATextFile
        
        var errorDescription: String? {
            switch self {
            case .notATextFile:
                return "Not a text file"
            }
        }
    }
}

private struct ContextBudgetDiagnosticsView: View {
    let diagnostics: ContextBuildResult
    let formatFileSize: (Int64) -> String
    let formatNumber: (Int) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorSection(title: "CONTEXT BUDGET") {
                budgetRow(
                    label: "Bytes",
                    value: diagnostics.totalBytes,
                    limit: diagnostics.budget.maxTotalBytes,
                    formattedValue: formatFileSize(Int64(diagnostics.totalBytes)),
                    formattedLimit: formatFileSize(Int64(diagnostics.budget.maxTotalBytes))
                )
                
                budgetRow(
                    label: "Tokens",
                    value: diagnostics.totalTokens,
                    limit: diagnostics.budget.maxTotalTokens,
                    formattedValue: "~\(formatNumber(diagnostics.totalTokens))",
                    formattedLimit: "~\(formatNumber(diagnostics.budget.maxTotalTokens))"
                )
            }
            
            if !diagnostics.truncatedFiles.isEmpty {
                InspectorDivider()
                InspectorSection(title: "TRIMMED FILES") {
                    ForEach(diagnostics.truncatedFiles) { file in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text(file.contextNote ?? "Trimmed to respect per-file limits.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            if !diagnostics.excludedFiles.isEmpty {
                InspectorDivider()
                InspectorSection(title: "EXCLUDED FILES") {
                    ForEach(diagnostics.excludedFiles) { exclusion in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exclusion.file.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text(exclusionMessage(for: exclusion.reason))
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
    
    private func budgetRow(label: String, value: Int, limit: Int, formattedValue: String, formattedLimit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formattedValue) / \(formattedLimit)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(progressColor(value: value, limit: limit))
            }
            ProgressView(value: Double(min(value, limit)), total: Double(limit))
                .tint(progressColor(value: value, limit: limit))
        }
    }
    
    private func progressColor(value: Int, limit: Int) -> Color {
        let ratio = Double(value) / Double(limit)
        if ratio >= 1 {
            return .red
        } else if ratio >= 0.85 {
            return .orange
        } else {
            return .accentColor
        }
    }
    
    private func exclusionMessage(for reason: ContextExclusionReason) -> String {
        switch reason {
        case .exceedsPerFileBytes(let limit):
            return "Removed because it exceeded \(formatFileSize(Int64(limit)))."
        case .exceedsPerFileTokens(let limit):
            return "Removed because it exceeded ~\(formatNumber(limit)) tokens."
        case .exceedsTotalBytes(let limit):
            return "Skipped because total byte budget (\(formatFileSize(Int64(limit)))) was reached."
        case .exceedsTotalTokens(let limit):
            return "Skipped because total token budget (~\(formatNumber(limit))) was reached."
        }
    }
}
