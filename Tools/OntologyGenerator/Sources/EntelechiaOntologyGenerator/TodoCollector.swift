// @EntelechiaHeaderStart
// Signifier: TodoCollector
// Substance: TODO collection
// Genus: Ontology analyzer
// Differentia: Collects all TODO items from headers and folders
// Form: Collection and aggregation rules
// Matter: File headers; folder headers
// Powers: Scan headers; collect TODOs; aggregate by type
// FinalCause: Surface ontology work items for completion
// Relations: Used by main.swift; uses HeaderParser
// CausalityType: Efficient
// @EntelechiaHeaderEnd

import Foundation

struct TodoCollector {
    struct ProjectTodos {
        let missingHeaders: [String]
        let missingFolderEnts: [String]
        let filesWithIncompleteHeaders: [String]
        let foldersWithIncompleteEnts: [String]
        let allTodos: [String]
    }
    
    /// Collect all TODOs from project
    static func collectTodos(swiftFiles: [URL], folders: [URL], appRoot: URL) -> ProjectTodos {
        var missingHeaders: [String] = []
        var missingFolderEnts: [String] = []
        var filesWithIncompleteHeaders: [String] = []
        var foldersWithIncompleteEnts: [String] = []
        var allTodos: [String] = []
        
        // Check Swift files
        for fileURL in swiftFiles {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }
            
            if let header = HeaderParser.parseHeader(from: content) {
                var fileTodos: [String] = []
                
                for key in HeaderParser.orderedKeys {
                    if let value = header[key], value.contains("TODO_AGENT_FILL") {
                        fileTodos.append("\(fileURL.path): Missing \(key)")
                    } else if header[key] == nil || header[key]?.isEmpty == true {
                        if key != "Signifier" {
                            fileTodos.append("\(fileURL.path): Missing \(key)")
                        }
                    }
                }
                
                if !fileTodos.isEmpty {
                    filesWithIncompleteHeaders.append(fileURL.path)
                    allTodos.append(contentsOf: fileTodos)
                }
            } else {
                missingHeaders.append(fileURL.path)
                allTodos.append("\(fileURL.path): Missing header")
            }
        }
        
        // Check folders
        for folderURL in folders {
            if ExclusionEngine.isForbiddenDirectory(url: folderURL) {
                continue
            }
            
            if !ExclusionEngine.isOntologyWritableDirectory(url: folderURL, appRoot: appRoot) {
                continue
            }
            
            let entURL = folderURL.appendingPathComponent("Folder.ent")
            
            if FileManager.default.fileExists(atPath: entURL.path) {
                if let content = try? String(contentsOf: entURL, encoding: .utf8),
                   let header = HeaderParser.parseFolderHeader(from: content) {
                    var folderTodos: [String] = []
                    
                    for key in HeaderParser.orderedKeys {
                        if let value = header[key], value.contains("TODO_AGENT_FILL") {
                            folderTodos.append("\(entURL.path): Missing \(key)")
                        } else if header[key] == nil || header[key]?.isEmpty == true {
                            if key != "Signifier" {
                                folderTodos.append("\(entURL.path): Missing \(key)")
                            }
                        }
                    }
                    
                    if !folderTodos.isEmpty {
                        foldersWithIncompleteEnts.append(folderURL.path)
                        allTodos.append(contentsOf: folderTodos)
                    }
                }
            } else {
                missingFolderEnts.append(folderURL.path)
                allTodos.append("\(folderURL.path): Missing Folder.ent")
            }
        }
        
        return ProjectTodos(
            missingHeaders: missingHeaders,
            missingFolderEnts: missingFolderEnts,
            filesWithIncompleteHeaders: filesWithIncompleteHeaders,
            foldersWithIncompleteEnts: foldersWithIncompleteEnts,
            allTodos: allTodos
        )
    }
}



