import Foundation
import AppCoreEngine

/// Immutable view state for workspace UI (pure form, no power).
/// Derived from WorkspaceStateViewModel and WorkspaceActivityViewModel, never mutated directly.
public struct WorkspaceViewState {
    public let selectedNode: FileNode?
    public let selectedDescriptorID: FileID?
    public let rootFileNode: FileNode?
    public let rootDirectory: URL?
    public let projectTodos: ProjectTodos
    public let todosError: Error?
    
    public init(
        selectedNode: FileNode?,
        selectedDescriptorID: FileID?,
        rootFileNode: FileNode?,
        rootDirectory: URL?,
        projectTodos: ProjectTodos,
        todosError: Error?
    ) {
        self.selectedNode = selectedNode
        self.selectedDescriptorID = selectedDescriptorID
        self.rootFileNode = rootFileNode
        self.rootDirectory = rootDirectory
        self.projectTodos = projectTodos
        self.todosError = todosError
    }
}

