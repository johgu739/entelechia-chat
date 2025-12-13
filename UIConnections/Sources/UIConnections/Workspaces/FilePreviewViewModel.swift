// @EntelechiaHeaderStart
// Signifier: FilePreviewViewModel
// Substance: File preview UI faculty
// Genus: Application faculty
// Differentia: Loads and presents file preview content
// Form: Preview loading rules
// Matter: File content; preview state
// Powers: Load file preview content asynchronously
// FinalCause: Display file preview in inspector
// Relations: Serves ContextInspector; depends on file models
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import Combine
import AppCoreEngine

@MainActor
public final class FilePreviewViewModel: ObservableObject {
    @Published public var content: String?
    @Published public var isLoading: Bool = false
    @Published public var error: Error?
    
    private var currentURL: URL?
    
    public init() {}
    
    public func loadPreview(for url: URL) async {
        // Skip if already loading the same URL
        guard currentURL != url else { return }
        
        currentURL = url
        isLoading = true
        error = nil
        content = nil
        
        do {
            let fileKind = FileTypeClassifier.kind(for: url)
            guard FileTypeClassifier.isTextLike(fileKind) else {
                error = FilePreviewError.notATextFile
                isLoading = false
                return
            }
            
            let loadTask = Task(priority: .utility) {
                if let data = try? Data(contentsOf: url),
                   let text = String(data: data, encoding: .utf8) {
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
    
    public func clear() {
        currentURL = nil
        content = nil
        error = nil
        isLoading = false
    }
    
    public enum FilePreviewError: LocalizedError {
        case notATextFile
        
        public var errorDescription: String? {
            switch self {
            case .notATextFile:
                return "Not a text file"
            }
        }
    }
}

