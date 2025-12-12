import Foundation

/// Immutable view state for workspace UI (pure form, no power).
public struct WorkspaceViewState: Equatable, Sendable {
    public let selectedNode: FileNode?
    public let selectedDescriptorID: FileID?
    public let rootFileNode: FileNode?
    public let rootDirectory: URL?
    public let projectTodos: ProjectTodos
    public let todosErrorDescription: String?
    
    public init(
        selectedNode: FileNode?,
        selectedDescriptorID: FileID?,
        rootFileNode: FileNode?,
        rootDirectory: URL?,
        projectTodos: ProjectTodos,
        todosErrorDescription: String?
    ) {
        self.selectedNode = selectedNode
        self.selectedDescriptorID = selectedDescriptorID
        self.rootFileNode = rootFileNode
        self.rootDirectory = rootDirectory
        self.projectTodos = projectTodos
        self.todosErrorDescription = todosErrorDescription
    }
}

