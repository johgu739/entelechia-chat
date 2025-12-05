// @EntelechiaHeaderStart
// Signifier: EntWriter
// Substance: Folder.ent file generation
// Genus: Ontology writer
// Differentia: Generates and writes Folder.ent and topology files
// Form: File writing with exclusion checks
// Matter: Folder URLs; header content
// Powers: Generate Folder.ent; write topology JSON; enforce whitelist
// FinalCause: Create ontology artifacts only in allowed directories
// Relations: Used by main.swift; uses ExclusionEngine, HeaderParser
// CausalityType: Efficient
// @EntelechiaHeaderEnd

import Foundation

struct EntWriter {
    /// Generate Folder.ent content for a folder
    /// Returns: (content, signifier, todos)
    static func generateFolderEnt(folderURL: URL, appRoot: URL) -> (content: String, signifier: String, todos: [String]) {
        let folderName = folderURL.lastPathComponent
        
        // Check if Folder.ent already exists
        let entURL = folderURL.appendingPathComponent("Folder.ent")
        if FileManager.default.fileExists(atPath: entURL.path) {
            if let existingContent = try? String(contentsOf: entURL, encoding: .utf8) {
                return HeaderParser.ensureFolderHeader(in: existingContent, folderName: folderName)
            }
        }
        
        // Generate new Folder.ent
        var fields: [String: String] = [
            "Signifier": folderName,
            "Genus": "Folder",
            "Form": "Contains ordered parts",
            "Matter": "Child files and subfolders",
            "Powers": "Provide ontological grouping",
            "FinalCause": "Order its contents toward their shared end"
        ]
        
        // Add TODOs for missing semantic fields
        var todos: [String] = []
        if fields["Substance"] == nil {
            fields["Substance"] = "TODO_AGENT_FILL"
            todos.append("\(folderName)/Folder.ent: Missing Substance")
        }
        if fields["Differentia"] == nil {
            fields["Differentia"] = "TODO_AGENT_FILL"
            todos.append("\(folderName)/Folder.ent: Missing Differentia")
        }
        if fields["Relations"] == nil {
            fields["Relations"] = "TODO_AGENT_FILL"
            todos.append("\(folderName)/Folder.ent: Missing Relations")
        }
        if fields["CausalityType"] == nil {
            fields["CausalityType"] = "TODO_AGENT_FILL"
            todos.append("\(folderName)/Folder.ent: Missing CausalityType")
        }
        
        let content = HeaderParser.renderFolderHeaderBlock(fields: fields)
        return (content, fields["Signifier"] ?? folderName, todos)
    }
    
    /// Write Folder.ent to disk (only if directory is ontology-writable)
    static func writeFolderEnt(folderURL: URL, appRoot: URL) throws {
        // CRITICAL: Only write to ontology-writable directories
        guard ExclusionEngine.isOntologyWritableDirectory(url: folderURL, appRoot: appRoot) else {
            throw OntologyError.forbiddenOntologyDirectory(folderURL.path)
        }
        
        let (content, _, _) = generateFolderEnt(folderURL: folderURL, appRoot: appRoot)
        let entURL = folderURL.appendingPathComponent("Folder.ent")
        try content.write(to: entURL, atomically: true, encoding: .utf8)
    }
    
    /// Write Folder.topology.json to disk
    static func writeTopology(folderURL: URL, topology: [String: Any], appRoot: URL) throws {
        // CRITICAL: Only write to ontology-writable directories
        guard ExclusionEngine.isOntologyWritableDirectory(url: folderURL, appRoot: appRoot) else {
            return // Silently skip forbidden directories
        }
        
        let jsonURL = folderURL.appendingPathComponent("Folder.topology.json")
        let jsonData = try JSONSerialization.data(withJSONObject: topology, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: jsonURL)
    }
}

enum OntologyError: Error {
    case forbiddenOntologyDirectory(String)
    
    var localizedDescription: String {
        switch self {
        case .forbiddenOntologyDirectory(let path):
            return "Cannot write ontology artifacts to forbidden directory: \(path)"
        }
    }
}

