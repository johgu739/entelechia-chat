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
import SwiftUI
import UniformTypeIdentifiers
import AppKit
import os.log
import Engine

private typealias FileExclusion = Engine.FileExclusion

enum FileNodeError: LocalizedError {
    case childCreationFailed(URL)
    case directoryReadFailed(URL, underlying: Error)
    case emptyProject(URL)

    var errorDescription: String? {
        switch self {
        case .childCreationFailed(let url):
            return "Could not represent \(url.lastPathComponent)"
        case .directoryReadFailed(let url, _):
            return "Could not read directory \(url.lastPathComponent)"
        case .emptyProject(let url):
            return "Project at \(url.lastPathComponent) contains no files"
        }
    }

    var failureReason: String? {
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

/// Unified file tree node used throughout the application
/// Can be used in both SwiftUI (OutlineGroup) and AppKit (NSOutlineView)
/// This is a value/entity type, not a view model, so it does not conform to ObservableObject
final class FileNode: Identifiable {
    private static let logger = Logger.persistence

    let id: UUID
    let name: String
    let path: URL
    var children: [FileNode]? = nil
    let icon: String
    let isParentDirectory: Bool // Special flag for ".." navigation
    let isDirectory: Bool
    private var childrenLoaded = false
    
    init(id: UUID? = nil, name: String, path: URL, children: [FileNode]? = nil, icon: String, isParentDirectory: Bool = false, isDirectory: Bool = false) {
        self.id = id ?? UUID()
        self.name = name
        self.path = path
        self.children = children
        self.icon = icon
        self.isParentDirectory = isParentDirectory
        self.isDirectory = isDirectory
        // If children are provided, mark them as loaded
        // If nil, they will be loaded lazily via loadChildrenIfNeeded()
        self.childrenLoaded = (children != nil)
    }
    
    /// Create a FileNode from a file system URL
    /// Returns nil for forbidden directories and files
    static func from(url: URL, includeParent: Bool = false, isParentDir: Bool = false) -> FileNode? {
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
            FileNode.logger.error("Could not read resource values for \(url.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            isDirectory = false
        }
        
        // For directories: children will be nil initially (lazy loading)
        // For files: children will be nil (they don't have children)
        let children: [FileNode]? = nil
        
        // Determine icon
        let icon: String
        if isDirectory {
            icon = "folder"
        } else {
            // File type icon
            let fileType = UTType(filenameExtension: url.pathExtension)
            if fileType?.conforms(to: .sourceCode) == true {
                icon = "doc.text"
            } else if fileType?.conforms(to: .text) == true {
                icon = "doc.text"
            } else if fileType?.conforms(to: .image) == true {
                icon = "photo"
            } else {
                icon = "doc"
            }
        }
        
        return FileNode(
            name: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
            path: url,
            children: children,
            icon: icon,
            isParentDirectory: false,
            isDirectory: isDirectory
        )
    }
    
    /// Load children lazily when expanded.
    /// Skolboksexempel: lista bara verkliga undermappar/filer under `path`.
    func loadChildrenIfNeeded(projectRoot: URL? = nil) throws {
        // Early return if already loaded or not a directory
        guard !childrenLoaded else { return }
        guard isDirectory else { return }
        
        // Mark as loaded immediately to prevent double-loading
        childrenLoaded = true
        
        let hasAccess = path.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                path.stopAccessingSecurityScopedResource()
            }
        }
        
        var directoryChildren: [FileNode] = []
        
        // Läs faktiska kataloginnehållet
        // NO FILTERS - show everything that exists in the directory
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: path,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .contentTypeKey],
                options: []
            )
            
            // Sort: directories first, then files, both alphabetically
            let sortedContents = contents.sorted { url1, url2 in
                let isDir1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                let isDir2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                
                if isDir1 != isDir2 {
                    return isDir1 // directories first
                }
                return url1.lastPathComponent.localizedCaseInsensitiveCompare(url2.lastPathComponent) == .orderedAscending
            }
            
            // Convert items to FileNodes, excluding forbidden directories and files
            for childURL in sortedContents {
                // Skip forbidden directories
                if FileExclusion.isForbiddenDirectory(url: childURL) {
                    continue
                }
                
                // Skip forbidden files
                if FileExclusion.isForbiddenFile(url: childURL) {
                    continue
                }
                
                if let childNode = FileNode.from(url: childURL, includeParent: false, isParentDir: false) {
                    directoryChildren.append(childNode)
                } else {
                    throw FileNodeError.childCreationFailed(childURL)
                }
            }
        } catch {
            throw FileNodeError.directoryReadFailed(path, underlying: error)
        }
        
        // If directory listing succeeded but we got no children:
        // - Root project directory must have content (fatal)
        // - Other directories may legitimately be empty
        if directoryChildren.isEmpty {
            if let projectRoot, projectRoot == path {
                throw FileNodeError.emptyProject(projectRoot)
            } else {
                children = []
                return
            }
        }
        
        children = directoryChildren
    }
    
    /// Ladda hela trädstrukturen under denna nod rekursivt.
    func loadRecursively(projectRoot: URL? = nil) throws {
        try loadChildrenIfNeeded(projectRoot: projectRoot)
        for child in children ?? [] {
            if child.isDirectory {
                try child.loadRecursively(projectRoot: projectRoot)
            }
        }
    }
    
    /// Reset children loading state (useful for refreshing)
    func resetChildren() {
        childrenLoaded = false
        children = nil
    }
}

extension FileNode {
    static let mockTree: [FileNode] = [
        FileNode(
            name: "EntelechiaOperator",
            path: URL(fileURLWithPath: "/EntelechiaOperator"),
            children: [
                FileNode(
                    name: "Sources",
                    path: URL(fileURLWithPath: "/EntelechiaOperator/Sources"),
                    children: [
                        FileNode(
                            name: "App",
                            path: URL(fileURLWithPath: "/EntelechiaOperator/Sources/App"),
                            children: [
                                FileNode(
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

extension FileNode {
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
}

extension Array where Element == FileNode {
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
}
