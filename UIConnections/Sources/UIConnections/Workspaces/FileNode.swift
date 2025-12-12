// @EntelechiaHeaderStart
// Signifier: FileNode
// Substance: File tree node
// Genus: Workspace data model
// Differentia: Represents directories/files with children
// Form: URL + children + directory flags
// Matter: Paths; icons; children arrays
// Powers: Represent and load directory structures
// FinalCause: Model the workspace file hierarchy
// Relations: Used by workspace services/VMs/UI
// CausalityType: Material
// @EntelechiaHeaderEnd

import Foundation
import os.log
import AppCoreEngine

private typealias FileExclusion = AppCoreEngine.FileExclusion

internal enum FileNodeError: LocalizedError {
    case childCreationFailed(URL)
    case directoryReadFailed(URL, underlying: Error)
    case emptyProject(URL)

    public var errorDescription: String? {
        switch self {
        case .childCreationFailed(let url):
            return "Could not represent \(url.lastPathComponent)"
        case .directoryReadFailed(let url, _):
            return "Could not read directory \(url.lastPathComponent)"
        case .emptyProject(let url):
            return "Project at \(url.lastPathComponent) contains no files"
        }
    }

    public var failureReason: String? {
        switch self {
        case .childCreationFailed(let url):
            return "The item at \(url.path) could not be represented in the navigator."
        case .directoryReadFailed(_, let underlying):
            return underlying.localizedDescription
        case .emptyProject:
            return "Select a folder that contains source files and directories."
        }
    }
}

/// Internal file tree node used for workspace coordination.
/// UIConnections uses this internally; external code should use UIContracts.FileNode.
/// This is a class with mutable children for internal coordination.
internal final class FileNode: Identifiable {
    private static let logger = Logger(subsystem: "UIConnections", category: "FileNode")

    /// UI identity (used by SwiftUI lists/outline).
    public let id: UUID
    /// Engine-issued identity, if this node was built from engine descriptors.
    public let descriptorID: FileID?
    public let name: String
    public let path: URL
    public var children: [FileNode]?
    public let icon: String
    public let isParentDirectory: Bool // Special flag for ".." navigation
    public let isDirectory: Bool
    
    public init(
        id: UUID? = nil,
        descriptorID: FileID? = nil,
        name: String,
        path: URL,
        children: [FileNode]? = nil,
        icon: String,
        isParentDirectory: Bool = false,
        isDirectory: Bool = false
    ) {
        self.id = id ?? UUID()
        self.descriptorID = descriptorID
        self.name = name
        self.path = path
        self.children = children
        self.icon = icon
        self.isParentDirectory = isParentDirectory
        self.isDirectory = isDirectory
    }
    
    /// Create a FileNode from a file system URL
    /// Returns nil for forbidden directories and files
    public static func from(url: URL, includeParent: Bool = false, isParentDir: Bool = false) -> FileNode? {
        // For parent directory nodes, create directly (never exclude parent navigation)
        if isParentDir {
            return FileNode(
                name: "..",
                path: url,
                children: nil,
                icon: "arrow.up.circle.fill",
                isParentDirectory: true
            )
        }
        
        // Exclude forbidden directories and files at creation time
        if FileExclusion.isForbiddenDirectory(url: url) || FileExclusion.isForbiddenFile(url: url) {
            return nil
        }
        
        // Try to access the resource (may fail for some URLs, but continue anyway)
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Get resource values - use do-catch for proper error handling
        var isDirectory = false
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            isDirectory = resourceValues.isDirectory == true
        } catch {
            FileNode.logger.error(
                "Could not read resource values for \(url.path, privacy: .private): " +
                "\(error.localizedDescription, privacy: .public)"
            )
            isDirectory = false
        }
        
        // For directories: children will be nil initially (lazy loading)
        // For files: children will be nil (they don't have children)
        let children: [FileNode]? = nil
        
        // Determine icon
        let icon = FileTypeClassifier.icon(for: url, isDirectory: isDirectory)
        
        return FileNode(
            descriptorID: nil,
            name: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
            path: url,
            children: children,
            icon: icon,
            isParentDirectory: false,
            isDirectory: isDirectory
        )
    }
    
}

internal extension FileNode {
    static let mockTree: [FileNode] = [
        FileNode(
            descriptorID: nil,
            name: "EntelechiaOperator",
            path: URL(fileURLWithPath: "/EntelechiaOperator"),
            children: [
                FileNode(
                    descriptorID: nil,
                    name: "Sources",
            path: URL(fileURLWithPath: "/EntelechiaOperator/Sources"),
                    children: [
                        FileNode(
                            descriptorID: nil,
                            name: "App",
                    path: URL(fileURLWithPath: "/EntelechiaOperator/Sources/App"),
                            children: [
                                FileNode(
                                    descriptorID: nil,
                                    name: "EntelechiaOperatorApp.swift",
                            path: URL(fileURLWithPath: "/EntelechiaOperator/Sources/App/EntelechiaOperatorApp.swift"),
                                    children: [],
                                    icon: "doc.text"
                                )
                            ],
                            icon: "folder"
                        )
                    ],
                    icon: "folder"
                )
            ],
            icon: "folder"
        )
    ]
}

internal extension FileNode {
    /// Recursively find a node by its ID in the tree
    func findNode(withID id: UUID) -> FileNode? {
        if self.id == id {
            return self
        }
        guard let children = children else { return nil }
        for child in children {
            if let found = child.findNode(withID: id) {
                return found
            }
        }
        return nil
    }
    
    /// Recursively find a node by its URL in the tree
    func findNode(withURL url: URL) -> FileNode? {
        if self.path == url {
            return self
        }
        guard let children = children else { return nil }
        for child in children {
            if let found = child.findNode(withURL: url) {
                return found
            }
        }
        return nil
    }

    /// Recursively find a node by its engine descriptor ID.
    func findNode(withDescriptorID descriptorID: FileID) -> FileNode? {
        if let current = self.descriptorID, current == descriptorID {
            return self
        }
        guard let children = children else { return nil }
        for child in children {
            if let found = child.findNode(withDescriptorID: descriptorID) {
                return found
            }
        }
        return nil
    }
}

internal extension Array where Element == FileNode {
    /// Recursively find a node by its ID
    func node(withID id: UUID) -> FileNode? {
        for node in self {
            if let found = node.findNode(withID: id) {
                return found
            }
        }
        return nil
    }
    
    /// Recursively find a node by its URL
    func node(withURL url: URL) -> FileNode? {
        for node in self {
            if let found = node.findNode(withURL: url) {
                return found
            }
        }
        return nil
    }

    /// Recursively find a node by its engine descriptor ID.
    func node(withDescriptorID descriptorID: FileID) -> FileNode? {
        for node in self {
            if let found = node.findNode(withDescriptorID: descriptorID) {
                return found
            }
        }
        return nil
    }
}

