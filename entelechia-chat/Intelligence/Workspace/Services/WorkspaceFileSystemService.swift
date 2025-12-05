// @EntelechiaHeaderStart
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

/// Service for workspace file system operations
final class WorkspaceFileSystemService {
    static let shared = WorkspaceFileSystemService()
    
    private init() {}
    
    /// Build a complete file tree for a given root URL
    /// Returns nil if root URL cannot be accessed or is invalid
    /// Throws fatal error if directory exists but cannot be read
    func buildTree(for rootURL: URL) -> FileNode? {
        // Validate that URL exists and is accessible
        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            return nil
        }
        
        // Create root node - if this fails, return nil
        guard let root = FileNode.from(url: rootURL, includeParent: false) else {
            return nil
        }
        
        // Load tree recursively - if this fails silently, we'll catch it in validation
        root.loadRecursively(projectRoot: rootURL)
        
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
