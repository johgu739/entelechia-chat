import Foundation

public struct FileID: Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public enum FileType: String, Codable, Sendable {
    case file
    case directory
}

/// Pure, UI-free workspace node representation.
public struct FileDescriptor: Codable, Sendable, Hashable {
    public let id: FileID
    public let name: String
    public let type: FileType
    public let children: [FileID]

    public init(id: FileID = FileID(), name: String, type: FileType, children: [FileID] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.children = children
    }
}

