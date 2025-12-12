import Foundation
import AppCoreEngine

/// Intent types for workspace interactions (value types, no mutation).
/// Intents are descriptive, not imperative - they describe what should happen.
public enum WorkspaceIntent {
    case selectNode(FileNode?)
    case selectDescriptorID(FileID?)
    case setContextInclusion(Bool, URL)
    case loadFilePreview(URL)
    case loadFileStats(URL)
    case loadFolderStats(URL)
    case clearFilePreview
    case clearFileStats
    case clearFolderStats
    case clearBanner
    case toggleExpanded(FileID)
    case setActiveNavigator(NavigatorMode)
    case setFilterText(String)
    case clearExpanded
}


