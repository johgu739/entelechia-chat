import Foundation

/// File tree node for UI display (pure value type, display properties only).
public struct FileNode: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let descriptorID: FileID?
    public let name: String
    public let path: URL
    public let children: [FileNode]?
    public let icon: String
    public let isParentDirectory: Bool
    public let isDirectory: Bool
    
    public init(
        id: UUID = UUID(),
        descriptorID: FileID? = nil,
        name: String,
        path: URL,
        children: [FileNode]? = nil,
        icon: String,
        isParentDirectory: Bool = false,
        isDirectory: Bool = false
    ) {
        self.id = id
        self.descriptorID = descriptorID
        self.name = name
        self.path = path
        self.children = children
        self.icon = icon
        self.isParentDirectory = isParentDirectory
        self.isDirectory = isDirectory
    }
}

