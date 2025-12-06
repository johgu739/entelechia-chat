import Foundation

/// Abstract file system operations needed by the Engine, expressed in IDs and descriptors.
public protocol FileSystemAccess: Sendable {
    func listChildren(of id: FileID) throws -> [FileDescriptor]
    func metadata(for id: FileID) throws -> FileMetadata
    func resolveRoot(at path: String) throws -> FileID
}

/// Metadata for a file descriptor.
public struct FileMetadata: Sendable {
    public let path: String
    public let isDirectory: Bool
    public let byteSize: Int?

    public init(path: String, isDirectory: Bool, byteSize: Int?) {
        self.path = path
        self.isDirectory = isDirectory
        self.byteSize = byteSize
    }
}

/// Abstract file content loader.
public protocol FileContentLoading: Sendable {
    func load(url: URL) async throws -> String
}

