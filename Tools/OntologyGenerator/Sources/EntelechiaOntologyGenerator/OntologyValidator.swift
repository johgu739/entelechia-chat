// @EntelechiaHeaderStart
// Signifier: OntologyValidator
// Substance: Ontology validation
// Genus: Ontology validator
// Differentia: Validates ontology integrity and detects violations
// Form: Validation rules and checks
// Matter: File system; header content
// Powers: Validate headers; check Signifier presence; detect forbidden artifacts
// FinalCause: Ensure ontology integrity and prevent drift
// Relations: Used by main.swift; uses ExclusionEngine, HeaderParser
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation

struct OntologyValidator {
    struct ValidationResult {
        var isValid: Bool = true
        var errors: [String] = []
        var warnings: [String] = []
    }
    
    /// Validate entire project ontology
    static func validateProject(rootURL: URL, appRoot: URL) -> ValidationResult {
        var result = ValidationResult()
        
        // Scan project
        let (swiftFiles, folders) = FileScanner.scanProject(rootURL: rootURL)
        
        // Validate Swift files
        for fileURL in swiftFiles {
            // Skip Package.swift - it cannot have headers (tools-version must be first line)
            if fileURL.lastPathComponent == "Package.swift" {
                continue
            }
            
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }
            
            if let header = HeaderParser.parseHeader(from: content) {
                // Check Signifier presence
                if header["Signifier"] == nil || header["Signifier"]?.isEmpty == true {
                    result.isValid = false
                    result.errors.append("\(fileURL.path): Missing Signifier field")
                }
                
                // Check Signifier placement (should be first)
                // This is handled by HeaderParser, but we validate here
                
                // Check for TODO markers
                for (key, value) in header {
                    if value.contains("TODO_AGENT_FILL") {
                        result.warnings.append("\(fileURL.path): \(key) needs agent completion")
                    }
                }
            } else {
                result.isValid = false
                result.errors.append("\(fileURL.path): Missing header")
            }
        }
        
        // Validate folders
        for folderURL in folders {
            // Skip forbidden directories
            if ExclusionEngine.isForbiddenDirectory(url: folderURL) {
                continue
            }
            
            // Check for Folder.ent
            let entURL = folderURL.appendingPathComponent("Folder.ent")
            if ExclusionEngine.isOntologyWritableDirectory(url: folderURL, appRoot: appRoot) {
                if FileManager.default.fileExists(atPath: entURL.path) {
                    if let content = try? String(contentsOf: entURL, encoding: .utf8),
                       let header = HeaderParser.parseFolderHeader(from: content) {
                        if header["Signifier"] == nil || header["Signifier"]?.isEmpty == true {
                            result.isValid = false
                            result.errors.append("\(entURL.path): Missing Signifier field")
                        }
                    }
                } else {
                    result.warnings.append("\(folderURL.path): Missing Folder.ent")
                }
            }
        }
        
        // Check for ontology artifacts in forbidden directories
        checkForbiddenArtifacts(rootURL: rootURL, result: &result)
        
        return result
    }
    
    /// Check for ontology artifacts in forbidden directories
    private static func checkForbiddenArtifacts(rootURL: URL, result: inout ValidationResult) {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return
        }
        
        for case let url as URL in enumerator {
            if ExclusionEngine.isForbiddenDirectory(url: url) {
                let entURL = url.appendingPathComponent("Folder.ent")
                let topologyURL = url.appendingPathComponent("Folder.topology.json")
                
                if FileManager.default.fileExists(atPath: entURL.path) {
                    result.isValid = false
                    result.errors.append("Ontology artifact in forbidden directory: \(entURL.path)")
                }
                
                if FileManager.default.fileExists(atPath: topologyURL.path) {
                    result.isValid = false
                    result.errors.append("Ontology artifact in forbidden directory: \(topologyURL.path)")
                }
                
                enumerator.skipDescendants()
            }
        }
    }
    
    /// Cleanup forbidden artifacts
    static func cleanupForbiddenArtifacts(rootURL: URL) -> Int {
        var cleaned = 0
        
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }
        
        for case let url as URL in enumerator {
            if ExclusionEngine.isForbiddenDirectory(url: url) {
                let entURL = url.appendingPathComponent("Folder.ent")
                let topologyURL = url.appendingPathComponent("Folder.topology.json")
                
                if FileManager.default.fileExists(atPath: entURL.path) {
                    try? FileManager.default.removeItem(at: entURL)
                    cleaned += 1
                }
                
                if FileManager.default.fileExists(atPath: topologyURL.path) {
                    try? FileManager.default.removeItem(at: topologyURL)
                    cleaned += 1
                }
                
                enumerator.skipDescendants()
            }
        }
        
        return cleaned
    }
}

