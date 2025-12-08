// @EntelechiaHeaderStart
// Signifier: FileViewModel
// Substance: File UI faculty
// Genus: Application faculty
// Differentia: Presents file info to UI
// Form: File-specific state/logic
// Matter: File metadata/contents bindings
// Powers: Provide file info to UI
// FinalCause: Render a file view coherently
// Relations: Serves UI; depends on file models
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreEngine

@MainActor
class FileViewModel: ObservableObject {
    @Published var loadedFiles: [WorkspaceLoadedFile] = []
    @Published var errorMessage: String?
    
    let budget: ContextBudget
    
    init(budget: ContextBudget? = nil) {
        self.budget = budget ?? .default
    }
    
    var includedFiles: [WorkspaceLoadedFile] {
        loadedFiles.filter { $0.isIncludedInContext }
    }
    
    var includedByteCount: Int {
        includedFiles.reduce(0) { $0 + $1.byteCount }
    }
    
    var includedTokenCount: Int {
        includedFiles.reduce(0) { $0 + $1.tokenEstimate }
    }
    
    func loadFile(from url: URL) async throws {
        // Check if file is text-based before reading
        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
        guard let contentType = resourceValues.contentType else {
            throw FileLoadError.unknownContentType
        }
        
        guard contentType.conforms(to: .text) || contentType.conforms(to: .sourceCode) else {
            throw FileLoadError.notATextFile
        }
        
        let name = url.lastPathComponent
        
        // Load content async with proper encoding
        let loadTask = Task(priority: .userInitiated) {
            // Try UTF-8 first
            if let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf8) {
                return text
            }
            // Fallback to system encoding
            return try String(contentsOf: url, encoding: .utf8)
        }
        let content = try await loadTask.value
        
        let fileType = UTType(filenameExtension: url.pathExtension)
        
        let file = WorkspaceLoadedFile(name: name, url: url, content: content, fileType: fileType)
        loadedFiles.append(file)
        errorMessage = nil
    }
    
    enum FileLoadError: LocalizedError {
        case unknownContentType
        case notATextFile
        case encodingFailed
        
        var errorDescription: String? {
            switch self {
            case .unknownContentType:
                return "Could not determine file type"
            case .notATextFile:
                return "File is not a text file"
            case .encodingFailed:
                return "Could not decode file content"
            }
        }
    }
    
    func removeFile(_ file: WorkspaceLoadedFile) {
        loadedFiles.removeAll { $0.id == file.id }
    }
    
    func toggleFileInclusion(_ file: WorkspaceLoadedFile) {
        if let index = loadedFiles.firstIndex(where: { $0.id == file.id }) {
            var updatedFile = loadedFiles[index]
            updatedFile.isIncludedInContext.toggle()
            loadedFiles[index] = updatedFile
        }
    }
    
    func clearFiles() {
        loadedFiles.removeAll()
    }
}
