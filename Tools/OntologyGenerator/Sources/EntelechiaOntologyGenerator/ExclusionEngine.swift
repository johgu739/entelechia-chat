// @EntelechiaHeaderStart
// Signifier: ExclusionEngine
// Substance: Exclusion boundary enforcement
// Genus: Ontology utility
// Differentia: Defines forbidden directories and files for ontology operations
// Form: Exclusion rules and checks
// Matter: URL paths
// Powers: Determine if directory/file is forbidden or ontology-writable
// FinalCause: Prevent ontology artifacts in forbidden locations
// Relations: Used by FileScanner, EntWriter, TopologyBuilder, OntologyValidator
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation

/// Central exclusion engine for ontology operations
/// Prevents ontology artifacts from being created in forbidden directories
enum ExclusionEngine {
    // MARK: - Forbidden Directory Names
    
    static let forbiddenNames: Set<String> = [
        ".git",
        ".swift-module-cache",
        ".build",
        "DerivedData",
        ".idea",
        ".vscode",
        "Pods",
        "Carthage",
        "node_modules",
        ".Trash",
        ".history",
        "tmp_home",
        ".tmp_home",
        "xcuserdata",
        "xcshareddata"
    ]
    
    // MARK: - Forbidden File Names
    
    static let forbiddenFileNames: Set<String> = [
        ".DS_Store",
        "Package.resolved",
        ".swiftpm"
    ]
    
    // MARK: - Forbidden File Extensions
    
    static let forbiddenExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic",
        "mp3", "wav",
        "ttf", "otf",
        "o", "swiftmodule", "swiftdoc",
        "xcuserstate", "xcworkspacedata"
    ]
    
    // MARK: - Ontology-Bearing Roots
    
    /// Top-level directories where ontology artifacts are allowed
    static let ontologyBearingRoots: Set<String> = [
        "Accidents",
        "Assets",
        "Documentation",
        "Infrastructure",
        "Intelligence",
        "Teleology",
        "Tools",
        "Scripts"
    ]
    
    // MARK: - Core Exclusion Logic
    
    /// Returns true if the directory is forbidden (should never be traversed or written to)
    static func isForbiddenDirectory(url: URL) -> Bool {
        let pathComponents = url.pathComponents
        
        // Check if any path component matches a forbidden name
        for component in pathComponents {
            if forbiddenNames.contains(component) {
                return true
            }
            
            // Exclude dot-prefixed directories (except explicitly whitelisted ones)
            if component.hasPrefix(".") {
                return true
            }
        }
        
        return false
    }
    
    /// Returns true if the file is forbidden
    static func isForbiddenFile(url: URL) -> Bool {
        let fileName = url.lastPathComponent
        
        if forbiddenFileNames.contains(fileName) {
            return true
        }
        
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty && forbiddenExtensions.contains(ext) {
            return true
        }
        
        return false
    }
    
    /// Returns true if the directory is an ontology-bearing root (whitelisted top-level)
    static func isOntologyBearingRoot(url: URL, appRoot: URL) -> Bool {
        // Get relative path from app root
        let relativePath = url.path.replacingOccurrences(of: appRoot.path + "/", with: "")
        let components = relativePath.components(separatedBy: "/")
        
        // Check if first component is an ontology-bearing root
        if let firstComponent = components.first, ontologyBearingRoots.contains(firstComponent) {
            return true
        }
        
        return false
    }
    
    /// Returns true if ontology artifacts can be written to this directory
    static func isOntologyWritableDirectory(url: URL, appRoot: URL) -> Bool {
        // Must not be forbidden AND must be under an ontology-bearing root
        return !isForbiddenDirectory(url: url) && isOntologyBearingRoot(url: url, appRoot: appRoot)
    }
}


