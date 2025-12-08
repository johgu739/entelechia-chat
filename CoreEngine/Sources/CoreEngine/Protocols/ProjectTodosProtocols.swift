import Foundation

/// Loader for ontology/project TODO manifests.
public protocol ProjectTodosLoading: Sendable {
    /// Load the todos manifest for a workspace root.
    /// - Parameter root: workspace root directory URL
    /// - Returns: decoded `ProjectTodos` or `.empty` when missing
    func loadTodos(for root: URL) throws -> ProjectTodos
}

