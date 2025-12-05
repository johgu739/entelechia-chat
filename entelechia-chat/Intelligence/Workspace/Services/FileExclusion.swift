// @EntelechiaHeaderStart
// Signifier: FileExclusion
// Substance: File exclusion utility
// Genus: Workspace utility
// Differentia: Filters forbidden directories and files from file tree
// Form: Exclusion rules and checks
// Matter: URL paths
// Powers: Determine if directory/file should be excluded
// FinalCause: Prevent forbidden directories from appearing in file tree
// Relations: Used by FileNode and WorkspaceFileSystemService
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation

/// Exclusion utility for workspace file tree building
/// Mirrors the logic from OntologyGenerator.ExclusionEngine
enum FileExclusion {
    static let forbiddenDirectoryNames: Set<String> = [
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
    
    static let forbiddenFileNames: Set<String> = [
        ".DS_Store",
        "Package.resolved",
        ".swiftpm"
    ]
    
    static let forbiddenExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic",
        "mp3", "wav",
        "ttf", "otf",
        "o", "swiftmodule", "swiftdoc",
        "xcuserstate", "xcworkspacedata"
    ]
    
    /// Returns true if the directory should be excluded from file tree
    static func isForbiddenDirectory(url: URL) -> Bool {
        let pathComponents = url.pathComponents
        
        for component in pathComponents {
            if forbiddenDirectoryNames.contains(component) {
                return true
            }
            
            // Exclude dot-prefixed directories (except explicitly allowed ones)
            if component.hasPrefix(".") {
                return true
            }
        }
        
        return false
    }
    
    /// Returns true if the file should be excluded from file tree
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
}
