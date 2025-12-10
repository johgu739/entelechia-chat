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
import Combine
import AppCoreEngine

@MainActor
public final class FileViewModel: ObservableObject {
    @Published public var loadedFiles: [WorkspaceLoadedFile] = []
    @Published public var errorMessage: String?
    
    public let budget: ContextBudget
    
    public init(budget: ContextBudget? = nil) {
        self.budget = budget ?? .default
    }
    
    public var includedFiles: [WorkspaceLoadedFile] {
        loadedFiles.filter { $0.isIncludedInContext }
    }
    
    public var includedByteCount: Int {
        includedFiles.reduce(0) { $0 + $1.byteCount }
    }
    
    public var includedTokenCount: Int {
        includedFiles.reduce(0) { $0 + $1.tokenEstimate }
    }
    
    public func loadFile(from url: URL) async throws {
        // Check if file is text-based before reading
        let fileKind = FileTypeClassifier.kind(for: url)
        guard FileTypeClassifier.isTextLike(fileKind) else {
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
        
        let file = WorkspaceLoadedFile(name: name, url: url, content: content, fileKind: fileKind)
        loadedFiles.append(file)
        errorMessage = nil
    }
    
    public enum FileLoadError: LocalizedError {
        case unknownContentType
        case notATextFile
        case encodingFailed
        
        public var errorDescription: String? {
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
    
    public func removeFile(_ file: WorkspaceLoadedFile) {
        loadedFiles.removeAll { $0.id == file.id }
    }
    
    public func toggleFileInclusion(_ file: WorkspaceLoadedFile) {
        if let index = loadedFiles.firstIndex(where: { $0.id == file.id }) {
            var updatedFile = loadedFiles[index]
            updatedFile.isIncludedInContext.toggle()
            loadedFiles[index] = updatedFile
        }
    }
    
    public func clearFiles() {
        loadedFiles.removeAll()
    }
}

