import Foundation

/// UI mirror of WorkspaceTreeProjection (using UUID instead of FileID).
public struct UIWorkspaceTree: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let children: [UIWorkspaceTree]
    
    public init(
        id: UUID,
        name: String,
        path: String,
        isDirectory: Bool,
        children: [UIWorkspaceTree]
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
    }
}


