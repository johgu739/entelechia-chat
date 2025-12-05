// @EntelechiaHeaderStart
// Signifier: main
// Substance: Ontology generator entry point
// Genus: Executable main
// Differentia: Orchestrates ontology generation workflow
// Form: Sequential processing pipeline
// Matter: Command-line arguments; file system
// Powers: Scan; parse; generate; validate
// FinalCause: Maintain ontology integrity across project
// Relations: Uses all ontology modules
// CausalityType: Efficient
// @EntelechiaHeaderEnd

import Foundation

// MARK: - Main Program

do {
    // Parse command line arguments
    let args = CommandLine.arguments
    guard args.count >= 2 else {
        print("Usage: entelechia-ontology [--validate-only] [--apply-renames] <project-root>")
        Darwin.exit(1)
    }
    
    var isValidateOnly = false
    var isApplyRenames = false
    var projectRootIndex = 1
    
    for (index, arg) in args.enumerated() {
        if arg == "--validate-only" {
            isValidateOnly = true
            projectRootIndex = index + 1
        } else if arg == "--apply-renames" {
            isApplyRenames = true
            projectRootIndex = index + 1
        }
    }
    
    guard projectRootIndex < args.count else {
        print("Error: Project root path required")
        Darwin.exit(1)
    }
    
    let projectRootPath = args[projectRootIndex]
    
    // CRITICAL: Use absolute path, never rely on currentDirectoryPath
    // Check for SRCROOT environment variable first (from Xcode build scripts)
    let rootPath: String
    if let srcRoot = ProcessInfo.processInfo.environment["SRCROOT"] {
        rootPath = srcRoot
    } else {
        rootPath = projectRootPath
    }
    
    let projectRootURL = URL(fileURLWithPath: rootPath)
    let appRootURL = projectRootURL.appendingPathComponent("entelechia-chat")
    
    // Determine app root (could be project root itself)
    let actualAppRoot = FileManager.default.fileExists(atPath: appRootURL.path) ? appRootURL : projectRootURL
    
    // Validate root exists
    guard FileManager.default.fileExists(atPath: projectRootURL.path) else {
        print("❌ Error: Project root does not exist: \(projectRootURL.path)")
        Darwin.exit(1)
    }
    
    print("🔍 Scanning project at: \(projectRootURL.path)")
    print("📁 App root: \(actualAppRoot.path)")
    
    // 1. Scan the project root
    let (swiftFiles, folders) = FileScanner.scanProject(rootURL: projectRootURL)
    print("📄 Found \(swiftFiles.count) Swift files")
    print("📂 Found \(folders.count) folders")
    
    if isValidateOnly {
        // Validation-only mode
        print("\n🔍 Running validation...")
        let validationResult = OntologyValidator.validateProject(rootURL: projectRootURL, appRoot: actualAppRoot)
        
        if !validationResult.errors.isEmpty {
            print("\n❌ Validation Errors:")
            for error in validationResult.errors {
                print("  - \(error)")
            }
        }
        
        if !validationResult.warnings.isEmpty {
            print("\n⚠️  Warnings:")
            for warning in validationResult.warnings {
                print("  - \(warning)")
            }
        }
        
        if validationResult.isValid {
            print("\n✅ Validation passed!")
            Darwin.exit(0)
        } else {
            print("\n❌ Validation failed!")
            Darwin.exit(1)
        }
    }
    
    // 2. Parse all headers and auto-insert missing Signifier
    print("\n📝 Processing headers...")
    var headerTodos: [String] = []
    var filesProcessed = 0
    
    for fileURL in swiftFiles {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            continue
        }
        
        let fileName = fileURL.lastPathComponent
        let (updatedContent, _, todos) = HeaderParser.ensureHeader(in: content, fileName: fileName)
        
        if updatedContent != content {
            try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)
            filesProcessed += 1
        }
        
        headerTodos.append(contentsOf: todos)
    }
    
    print("  ✅ Updated \(filesProcessed) files with headers")
    
    // 3. Generate Folder.ent files (if missing)
    print("\n📋 Generating Folder.ent files...")
    var foldersProcessed = 0
    
    for folderURL in folders {
        if ExclusionEngine.isForbiddenDirectory(url: folderURL) {
            continue
        }
        
        if ExclusionEngine.isOntologyWritableDirectory(url: folderURL, appRoot: actualAppRoot) {
            do {
                try EntWriter.writeFolderEnt(folderURL: folderURL, appRoot: actualAppRoot)
                foldersProcessed += 1
            } catch {
                // Skip forbidden directories silently
            }
        }
    }
    
    print("  ✅ Processed \(foldersProcessed) folders")
    
    // 4. Generate Folder.topology.json files
    print("\n🗺️  Generating topology files...")
    var topologyFilesCreated = 0
    
    for folderURL in folders {
        if ExclusionEngine.isForbiddenDirectory(url: folderURL) {
            continue
        }
        
        if ExclusionEngine.isOntologyWritableDirectory(url: folderURL, appRoot: actualAppRoot) {
            if let topology = TopologyBuilder.buildFolderTopology(
                folderURL: folderURL,
                swiftFiles: swiftFiles,
                folders: folders,
                appRoot: actualAppRoot
            ) {
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
                
                do {
                    try EntWriter.writeTopology(folderURL: folderURL, topology: topologyDict, appRoot: actualAppRoot)
                    topologyFilesCreated += 1
                } catch {
                    // Skip silently
                }
            }
        }
    }
    
    print("  ✅ Created \(topologyFilesCreated) topology files")
    
    // 5. Generate ProjectTopology.json
    print("\n📊 Generating ProjectTopology.json...")
    let projectTopology = TopologyBuilder.buildProjectTopology(
        folders: folders,
        swiftFiles: swiftFiles,
        appRoot: actualAppRoot
    )
    
    // CRITICAL: Write to actualAppRoot, not projectRootURL, to maintain formal unity
    // Validate path exists before writing
    guard FileManager.default.fileExists(atPath: actualAppRoot.path) else {
        print("  ❌ Error: App root does not exist: \(actualAppRoot.path)")
        Darwin.exit(1)
    }
    
    let projectTopologyURL = actualAppRoot.appendingPathComponent("ProjectTopology.json")
    if let jsonData = try? JSONSerialization.data(withJSONObject: projectTopology, options: [.prettyPrinted, .sortedKeys]) {
        try? jsonData.write(to: projectTopologyURL)
        print("  ✅ Created ProjectTopology.json at \(projectTopologyURL.path)")
    }
    
    // 6. Generate RenameSuggestions.ent.json
    print("\n🔄 Generating rename suggestions...")
    let renameSuggestions = RenameSuggestionsGenerator.generateSuggestions(swiftFiles: swiftFiles)
    let suggestionsDict: [String: Any] = [
        "generatedAt": ISO8601DateFormatter().string(from: Date()),
        "suggestions": renameSuggestions.map { suggestion in
            [
                "currentPath": suggestion.currentPath,
                "currentName": suggestion.currentName,
                "signifier": suggestion.signifier,
                "genus": suggestion.genus ?? "",
                "differentia": suggestion.differentia ?? "",
                "proposedName": suggestion.proposedName,
                "confidence": suggestion.confidence,
                "reason": suggestion.reason
            ]
        }
    ]
    
    let suggestionsURL = projectRootURL.appendingPathComponent("OntologyRenameSuggestions.ent.json")
    if let jsonData = try? JSONSerialization.data(withJSONObject: suggestionsDict, options: [.prettyPrinted, .sortedKeys]) {
        try? jsonData.write(to: suggestionsURL)
        print("  ✅ Created OntologyRenameSuggestions.ent.json (\(renameSuggestions.count) suggestions)")
    }
    
    // 7. Generate ProjectTodos.ent.json
    print("\n📋 Generating TODO manifest...")
    let todos = TodoCollector.collectTodos(swiftFiles: swiftFiles, folders: folders, appRoot: actualAppRoot)
    let todosDict: [String: Any] = [
        "generatedAt": ISO8601DateFormatter().string(from: Date()),
        "missingHeaders": todos.missingHeaders,
        "missingFolderEnts": todos.missingFolderEnts,
        "filesWithIncompleteHeaders": todos.filesWithIncompleteHeaders,
        "foldersWithIncompleteEnts": todos.foldersWithIncompleteEnts,
        "allTodos": todos.allTodos
    ]
    
    let todosURL = projectRootURL.appendingPathComponent("ProjectTodos.ent.json")
    if let jsonData = try? JSONSerialization.data(withJSONObject: todosDict, options: [.prettyPrinted, .sortedKeys]) {
        try? jsonData.write(to: todosURL)
        print("  ✅ Created ProjectTodos.ent.json (\(todos.allTodos.count) TODOs)")
    }
    
    // 8. Run validation (fail on missing Signifier)
    print("\n🔍 Running validation...")
    let validationResult = OntologyValidator.validateProject(rootURL: projectRootURL, appRoot: actualAppRoot)
    
    if !validationResult.errors.isEmpty {
        print("\n❌ Validation Errors:")
        for error in validationResult.errors {
            print("  - \(error)")
        }
    }
    
    if !validationResult.warnings.isEmpty {
        print("\n⚠️  Warnings:")
        for warning in validationResult.warnings {
            print("  - \(warning)")
        }
    }
    
    // 9. Exit cleanly
    if validationResult.isValid {
        print("\n✅ Ontology generation complete!")
        print("\n📊 Summary:")
        print("  - Files scanned: \(swiftFiles.count)")
        print("  - Folders processed: \(foldersProcessed)")
        print("  - Headers updated: \(filesProcessed)")
        print("  - Topology files: \(topologyFilesCreated)")
        print("  - Rename suggestions: \(renameSuggestions.count)")
        print("  - TODOs: \(todos.allTodos.count)")
        Darwin.exit(0)
    } else {
        print("\n❌ Validation failed - please fix errors above")
        Darwin.exit(1)
    }
    
} catch {
    print("❌ Error: \(error.localizedDescription)")
    Darwin.exit(1)
}

