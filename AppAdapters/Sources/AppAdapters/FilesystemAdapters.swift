import Foundation
import CoreEngine
import os.lock

/// File system adapter using Foundation's FileManager, producing pure FileDescriptors.
public final class FileSystemAccessAdapter: FileSystemAccess, @unchecked Sendable {
    private let fileManager: FileManager
    private var pathToID: [String: FileID] = [:]
    private var idToPath: [FileID: String] = [:]
    private var lock = os_unfair_lock_s()

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func resolveRoot(at path: String) throws -> FileID {
        try ensureIDs(for: path)
    }

    public func listChildren(of id: FileID) throws -> [FileDescriptor] {
        guard let path = idToPath[id] else { return [] }
        let url = URL(fileURLWithPath: path)
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        var descriptors: [FileDescriptor] = []
        for child in contents {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let childPath = child.path
            let childID = try ensureIDs(for: childPath)
            descriptors.append(FileDescriptor(id: childID, name: child.lastPathComponent, type: isDir ? .directory : .file, children: []))
        }
        return descriptors
    }

    public func metadata(for id: FileID) throws -> FileMetadata {
        guard let path = idToPath[id] else {
            return FileMetadata(path: "", isDirectory: false, byteSize: nil)
        }
        let url = URL(fileURLWithPath: path)
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        let isDir = values?.isDirectory ?? false
        let size = values?.fileSize
        return FileMetadata(path: path, isDirectory: isDir, byteSize: size)
    }

    // MARK: - Helpers
    @discardableResult
    private func ensureIDs(for path: String) throws -> FileID {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        if let existing = pathToID[path] {
            return existing
        }
        let id = FileID()
        pathToID[path] = id
        idToPath[id] = path
        return id
    }
}

/// File content loader adapter.
public final class FileContentLoaderAdapter: FileContentLoading, @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func load(url: URL) async throws -> String {
        return try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "FileContentLoaderAdapter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to decode file as UTF-8"])
            }
            return content
        }.value
    }
}

