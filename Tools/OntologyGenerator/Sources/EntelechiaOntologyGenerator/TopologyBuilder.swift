// @EntelechiaHeaderStart
// Signifier: TopologyBuilder
// Substance: Topology metadata construction
// Genus: Ontology builder
// Differentia: Builds folder and project topology structures
// Form: Tree construction from file metadata
// Matter: File URLs; header metadata
// Powers: Build folder topology; aggregate project topology
// FinalCause: Represent project structure as ontology graph
// Relations: Used by main.swift; uses HeaderParser, FileScanner
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation

struct TopologyBuilder {
    struct FileInfo {
        let path: String
        let signifier: String
        let substance: String?
        let finalCause: String?
        let relations: String?
    }
    
    struct FolderTopology {
        let path: String
        let signifier: String
        let parentSignifier: String?
        let childFolders: [String]
        let childFiles: [FileInfo]
    }
    
    /// Build topology for a folder
    static func buildFolderTopology(
        folderURL: URL,
        swiftFiles: [URL],
        folders: [URL],
        appRoot: URL
    ) -> FolderTopology? {
        // Skip forbidden directories
        if ExclusionEngine.isForbiddenDirectory(url: folderURL) {
            return nil
        }
        
        // Only process ontology-writable directories
        guard ExclusionEngine.isOntologyWritableDirectory(url: folderURL, appRoot: appRoot) else {
            return nil
        }
        
        let folderName = folderURL.lastPathComponent
        let folderPath = folderURL.path
        
        // Get parent folder signifier
        let parentURL = folderURL.deletingLastPathComponent()
        let parentSignifier = parentURL.path != appRoot.path ? parentURL.lastPathComponent : nil
        
        // Find child folders
        let childFolders = folders
            .filter { $0.deletingLastPathComponent().path == folderPath }
            .map { $0.lastPathComponent }
        
        // Find child files
        let childFiles = swiftFiles
            .filter { $0.deletingLastPathComponent().path == folderPath }
            .compactMap { fileURL -> FileInfo? in
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8),
                      let header = HeaderParser.parseHeader(from: content) else {
                    return FileInfo(
                        path: fileURL.path,
                        signifier: fileURL.deletingPathExtension().lastPathComponent,
                        substance: nil,
                        finalCause: nil,
                        relations: nil
                    )
                }
                
                return FileInfo(
                    path: fileURL.path,
                    signifier: header["Signifier"] ?? fileURL.deletingPathExtension().lastPathComponent,
                    substance: header["Substance"],
                    finalCause: header["FinalCause"],
                    relations: header["Relations"]
                )
            }
        
        // Get folder signifier from Folder.ent if it exists
        let entURL = folderURL.appendingPathComponent("Folder.ent")
        var folderSignifier = folderName
        if let entContent = try? String(contentsOf: entURL, encoding: .utf8),
           let folderHeader = HeaderParser.parseFolderHeader(from: entContent) {
            folderSignifier = folderHeader["Signifier"] ?? folderName
        }
        
        return FolderTopology(
            path: folderPath,
            signifier: folderSignifier,
            parentSignifier: parentSignifier,
            childFolders: childFolders,
            childFiles: childFiles
        )
    }
    
    /// Build project topology from all folders
    static func buildProjectTopology(
        folders: [URL],
        swiftFiles: [URL],
        appRoot: URL
    ) -> [String: Any] {
        var projectTopology: [String: Any] = [:]
        var folderTopologies: [[String: Any]] = []
        
        for folderURL in folders {
            if let topology = buildFolderTopology(folderURL: folderURL, swiftFiles: swiftFiles, folders: folders, appRoot: appRoot) {
                let topologyDict: [String: Any] = [
                    "path": topology.path,
                    "signifier": topology.signifier,
                    "parentSignifier": topology.parentSignifier ?? "",
                    "childFolders": topology.childFolders,
                    "childFiles": topology.childFiles.map { file in
                        [
                            "path": file.path,
                            "signifier": file.signifier,
                            "substance": file.substance ?? "",
                            "finalCause": file.finalCause ?? "",
                            "relations": file.relations ?? ""
                        ]
                    }
                ]
                folderTopologies.append(topologyDict)
            }
        }
        
        projectTopology["folders"] = folderTopologies
        projectTopology["generatedAt"] = ISO8601DateFormatter().string(from: Date())
        
        return projectTopology
    }
}


