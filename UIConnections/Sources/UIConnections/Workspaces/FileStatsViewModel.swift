// @EntelechiaHeaderStart
// Signifier: FileStatsViewModel
// Substance: File statistics UI faculty
// Genus: Application faculty
// Differentia: Loads and presents file statistics
// Form: Statistics loading rules
// Matter: File size, line count, token estimates
// Powers: Load file statistics asynchronously
// FinalCause: Display file statistics in inspector
// Relations: Serves ContextInspector; depends on FileMetadataViewModel
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import Combine
import AppCoreEngine

@MainActor
public final class FileStatsViewModel: ObservableObject {
    @Published public var size: Int64?
    @Published public var lineCount: Int?
    @Published public var tokenEstimate: Int?
    @Published public var isLoading: Bool = false
    
    private let metadataViewModel: FileMetadataViewModel
    private var currentURL: URL?
    
    public init(metadataViewModel: FileMetadataViewModel) {
        self.metadataViewModel = metadataViewModel
    }
    
    public func loadStats(for url: URL) async {
        // Skip if already loading the same URL
        guard currentURL != url else { return }
        
        currentURL = url
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
            // Log error but don't fail completely
            print("Failed to get file size: \(error.localizedDescription)")
        }
        
        lineCount = await metadataViewModel.lineCount(for: url)
        isLoading = false
    }
    
    public func clear() {
        currentURL = nil
        size = nil
        lineCount = nil
        tokenEstimate = nil
        isLoading = false
    }
}

