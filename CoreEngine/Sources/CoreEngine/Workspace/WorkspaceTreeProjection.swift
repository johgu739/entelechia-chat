import Foundation

public struct WorkspaceTreeProjection: Sendable {
    public let id: FileID
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let children: [WorkspaceTreeProjection]

    public init(
        id: FileID,
        name: String,
        path: String,
        isDirectory: Bool,
        children: [WorkspaceTreeProjection]
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
    }
}

