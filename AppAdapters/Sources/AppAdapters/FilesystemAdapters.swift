import Foundation
import AppCoreEngine
import UniformTypeIdentifiers
import os

/// File system adapter using Foundation's FileManager, producing pure FileDescriptors.
///
/// Invariant: path→ID and ID→path mappings remain stable across listings for the same filesystem entries.
/// Concurrency: internal maps are guarded by `OSAllocatedUnfairLock`; uses FileManager which is thread-safe
/// for these calls. Marked `@unchecked Sendable` because `FileManager` and the lock wrapper are not statically
/// Sendable.
public final class FileSystemAccessAdapter: FileSystemAccess, @unchecked Sendable {
    private let state = FileIDState()

    public init() {}

    public func resolveRoot(at path: String) throws -> FileID {
        ensureIDs(for: path)
    }

    public func listChildren(of id: FileID) throws -> [FileDescriptor] {
        guard let path = state.path(for: id) else { return [] }
        let url = URL(fileURLWithPath: path)
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        var descriptors: [FileDescriptor] = []
        for child in contents {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let childPath = child.path
            let childID = ensureIDs(for: childPath)
            descriptors.append(FileDescriptor(id: childID, name: child.lastPathComponent, type: isDir ? .directory : .file, children: []))
        }
        return descriptors
    }

    public func metadata(for id: FileID) throws -> FileMetadata {
        guard let path = state.path(for: id) else {
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
    private func ensureIDs(for path: String) -> FileID {
        state.ensureIDs(for: path)
    }
}

// Thread-safe mapping between paths and FileID values.
private struct FileIDState: Sendable {
    private let lock = OSAllocatedUnfairLock<State>(initialState: State())

    private struct State {
        var idForPath: [String: FileID] = [:]
        var pathForID: [FileID: String] = [:]
    }

    func ensureIDs(for path: String) -> FileID {
        lock.withLock { state in
            if let existing = state.idForPath[path] {
                return existing
            }
            let id = FileID()
            state.idForPath[path] = id
            state.pathForID[id] = path
            return id
        }
    }

    func path(for id: FileID) -> String? {
        lock.withLock { state in state.pathForID[id] }
    }
}

/// File content loader adapter.
public actor FileContentLoaderAdapter: FileContentLoading {
    private let fileManager: FileManager
    private let maxBytes: Int

    public init(fileManager: FileManager = .default, maxBytes: Int = 1_000_000) {
        self.fileManager = fileManager
        self.maxBytes = maxBytes
    }

    public func load(url: URL) async throws -> String {
        let values = try url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
        if let size = values.fileSize, size > self.maxBytes {
            throw FileContentLoaderError.tooLarge(bytes: size, limit: self.maxBytes)
        }
        guard let contentType = values.contentType, contentType.conforms(to: .text) || contentType.conforms(to: .sourceCode) else {
            throw FileContentLoaderError.unsupportedType
        }
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw FileContentLoaderError.unreadable
        }
        return content
    }
}

public enum FileContentLoaderError: LocalizedError {
    case tooLarge(bytes: Int, limit: Int)
    case unsupportedType
    case unreadable

    public var errorDescription: String? {
        switch self {
        case .tooLarge(let bytes, let limit):
            return "File too large (\(bytes) bytes, limit \(limit))"
        case .unsupportedType:
            return "File is not text/source"
        case .unreadable:
            return "Unable to decode file as UTF-8"
        }
    }
}

