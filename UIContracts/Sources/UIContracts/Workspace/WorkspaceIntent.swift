import Foundation

/// Workspace user intents.
public enum WorkspaceIntent: Sendable, Equatable {
    case openWorkspace(URL)
    case selectPath(URL?)
    case selectDescriptor(UUID?)
    case toggleExpanded(UUID)
    case setContextInclusion(Bool, URL)
}

