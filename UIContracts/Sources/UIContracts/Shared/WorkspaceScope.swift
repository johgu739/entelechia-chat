import Foundation

/// Workspace scope for queries (using UUID instead of FileID).
public enum WorkspaceScope: Equatable, Sendable {
    case descriptor(UUID)
    case path(String)
    case selection
}

