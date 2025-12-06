// @EntelechiaHeaderStart
// Signifier: WorkspaceFileSystemService
// Substance: File tree faculty
// Genus: Workspace domain faculty
// Differentia: Builds and queries file trees
// Form: Tree construction and lookup rules
// Matter: URLs; FileNode graph
// Powers: Build tree; find nodes; create nodes
// FinalCause: Represent workspace structure intelligibly
// Relations: Serves workspace VMs; depends on FileNode
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import UniformTypeIdentifiers

enum WorkspaceFileSystemError: LocalizedError {
    case missingRoot(URL)
    case invalidRoot(URL)

    var errorDescription: String? {
        switch self {
        case .missingRoot(let url):
            return "Project folder missing at \(url.path)"
        case .invalidRoot(let url):
            return "Project folder is invalid at \(url.path)"
        }
    }

    var failureReason: String? {
        switch self {
        case .missingRoot(let url):
            return "No file system entity was found at \(url.path)."
        case .invalidRoot(let url):
            return "The directory at \(url.path) could not be represented."
        }
    }
}

/// Service for workspace file system operations
final class WorkspaceFileSystemService {
    private static var _shared = WorkspaceFileSystemService()
    static var shared: WorkspaceFileSystemService { _shared }
    
    static func configureShared(fileManager: FileManager) {
        _shared = WorkspaceFileSystemService(fileManager: fileManager)
    }
    
    private let fileManager: FileManager
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    /// Build a complete file tree for a given root URL
    /// Returns a fully materialized file tree or throws when invalid.
    func buildTree(for rootURL: URL) throws -> FileNode {
        // Validate that URL exists and is accessible
        guard fileManager.fileExists(atPath: rootURL.path) else {
            throw WorkspaceFileSystemError.missingRoot(rootURL)
        }
        
        // Create root node - if this fails, return nil
        guard let root = FileNode.from(url: rootURL, includeParent: false) else {
            throw WorkspaceFileSystemError.invalidRoot(rootURL)
        }
        
        try root.loadRecursively(projectRoot: rootURL)
        
        return root
    }
    
    /// Find a node in a tree by URL
    func findNode(withURL url: URL, in tree: FileNode?) -> FileNode? {
        tree?.findNode(withURL: url)
    }
    
    /// Create a standalone file node for a URL
    func createFileNode(for url: URL) -> FileNode? {
        FileNode.from(url: url, includeParent: false)
    }
}
