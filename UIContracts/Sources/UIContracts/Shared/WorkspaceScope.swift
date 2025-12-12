import Foundation

/// Workspace scope for queries (pure form, no domain semantics).
public enum WorkspaceScope: Equatable, Sendable {
    case descriptor(FileID)
    case path(String)
    case selection
}

