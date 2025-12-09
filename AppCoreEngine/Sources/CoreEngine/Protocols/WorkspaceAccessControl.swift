import Foundation

/// Resolves and canonicalizes workspace roots while enforcing boundary constraints.
public protocol WorkspaceRootProviding: Sendable {
    func canonicalRoot(for path: String) throws -> String
}

/// Filters workspace paths to keep Codex-visible areas safe.
public protocol WorkspaceBoundaryFiltering: Sendable {
    /// Returns true when the canonical path is allowed for traversal and exposure.
    func allows(canonicalPath: String) -> Bool
}

