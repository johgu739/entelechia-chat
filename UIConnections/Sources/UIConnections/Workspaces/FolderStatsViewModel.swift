// @EntelechiaHeaderStart
// Signifier: FolderStatsViewModel
// Substance: Folder statistics UI faculty
// Genus: Application faculty
// Differentia: Loads and presents folder statistics
// Form: Statistics loading rules
// Matter: Folder size, file counts, token estimates
// Powers: Load folder statistics asynchronously
// FinalCause: Display folder statistics in inspector
// Relations: Serves ContextInspector; depends on FileMetadataViewModel
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import Combine
import AppCoreEngine

@MainActor
public final class FolderStatsViewModel: ObservableObject {
    @Published public var stats: FileMetadataViewModel.FolderStats?
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
        stats = await metadataViewModel.folderStats(for: url)
        isLoading = false
    }
    
    public func clear() {
        currentURL = nil
        stats = nil
        isLoading = false
    }
}
