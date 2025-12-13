// @EntelechiaHeaderStart
// Signifier: FileScanner
// Substance: File system traversal
// Genus: Ontology scanner
// Differentia: Recursively scans project files respecting exclusion rules
// Form: Directory traversal with exclusion filtering
// Matter: File system URLs
// Powers: Find Swift files; find folders; respect exclusion boundaries
// FinalCause: Collect all ontology-bearing files for processing
// Relations: Used by main.swift; uses ExclusionEngine
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation

struct FileScanner {
    /// Scan project root and return all Swift files and folders
    /// Respects ExclusionEngine boundaries
    static func scanProject(rootURL: URL) -> (swiftFiles: [URL], folders: [URL]) {
        var swiftFiles: [URL] = []
        var folders: [URL] = []
        
        func scanDirectory(_ url: URL) {
            // Skip forbidden directories
            if ExclusionEngine.isForbiddenDirectory(url: url) {
                return
            }
            
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles],
                errorHandler: nil
            ) else {
                return
            }
            
            for case let fileURL as URL in enumerator {
                // Skip forbidden directories
                if ExclusionEngine.isForbiddenDirectory(url: fileURL) {
                    enumerator.skipDescendants()
                    continue
                }
                
                // Skip forbidden files
                if ExclusionEngine.isForbiddenFile(url: fileURL) {
                    continue
                }
                
                // Check if it's a directory
                if let isDirectory = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDirectory == true {
                    folders.append(fileURL)
                } else if fileURL.pathExtension == "swift" {
                    swiftFiles.append(fileURL)
                }
            }
        }
        
        scanDirectory(rootURL)
        return (swiftFiles, folders)
    }
}



