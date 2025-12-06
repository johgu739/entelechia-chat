// @EntelechiaHeaderStart
// Signifier: FileContentService
// Substance: Workspace content faculty
// Genus: Workspace domain faculty
// Differentia: Collects file contents recursively
// Form: Traversal and inclusion rules
// Matter: File nodes; loaded files; context flags
// Powers: Traverse tree; read contents; filter inclusion
// FinalCause: Supply contextual files for conversations
// Relations: Serves conversation faculty; depends on file models
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import UniformTypeIdentifiers
import CoreEngine

private typealias FileExclusion = CoreEngine.FileExclusion

/// Service for reading file content with proper error handling
final class FileContentService {
    static let shared = FileContentService()
    
    private init() {}
    
    /// Load file content with proper error handling and encoding detection
    /// Excludes forbidden files from being loaded
    /// CRITICAL: Every code path must return String or throw - no unused expressions
    func loadContent(at url: URL) async throws -> String {
        // Skip forbidden files
        if FileExclusion.isForbiddenFile(url: url) {
            throw FileContentError.notATextFile
        }
        
        // Perform I/O on background thread
        return try await Task.detached(priority: .userInitiated) {
            // Check if file is text-based before reading
            let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey])
            guard let contentType = resourceValues?.contentType else {
                throw FileContentError.unknownContentType
            }
            
            // Only read text files
            guard contentType.conforms(to: .text) || contentType.conforms(to: .sourceCode) else {
                throw FileContentError.notATextFile
            }
            
            // Try to read with UTF-8 first
            if let data = try? Data(contentsOf: url),
               let content = String(data: data, encoding: .utf8) {
                return content
            }
            
            // Fallback: try reading with UTF-8 encoding - MUST return
            return try String(contentsOf: url, encoding: .utf8)
        }.value
    }
    
    /// Collect all files from a file node (recursively for folders)
    /// Excludes forbidden directories and files from context collection
    func collectFiles(from node: FileNode) async throws -> [WorkspaceLoadedFile] {
        // Skip forbidden directories and files
        if FileExclusion.isForbiddenDirectory(url: node.path) || FileExclusion.isForbiddenFile(url: node.path) {
            return []
        }
        
        var files: [WorkspaceLoadedFile] = []
        
        // If node is a file, return only its content
        if node.children == nil || node.children?.isEmpty == true {
            let content = try await loadContent(at: node.path)
            let fileType = UTType(filenameExtension: node.path.pathExtension)
            let loadedFile = WorkspaceLoadedFile(
                name: node.name,
                url: node.path,
                content: content,
                fileType: fileType,
                isIncludedInContext: true
            )
            files.append(loadedFile)
            return files
        }
        
        // If node is a folder, recursively collect all files
        try await collectFilesRecursively(from: node, into: &files)
        return files
    }
    
    private func collectFilesRecursively(from node: FileNode, into files: inout [WorkspaceLoadedFile]) async throws {
        // Skip forbidden directories and files
        if FileExclusion.isForbiddenDirectory(url: node.path) || FileExclusion.isForbiddenFile(url: node.path) {
            return
        }
        
        if node.children == nil || node.children?.isEmpty == true {
            // It's a file - collect it
            let content = try await loadContent(at: node.path)
            let fileType = UTType(filenameExtension: node.path.pathExtension)
            let loadedFile = WorkspaceLoadedFile(
                name: node.name,
                url: node.path,
                content: content,
                fileType: fileType,
                isIncludedInContext: true
            )
            files.append(loadedFile)
        } else {
            // It's a folder, recurse into children
            for child in node.children ?? [] {
                try await collectFilesRecursively(from: child, into: &files)
            }
        }
    }
}

enum FileContentError: LocalizedError {
    case unknownContentType
    case notATextFile
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .unknownContentType:
            return "Could not determine file type"
        case .notATextFile:
            return "File is not a text file"
        case .encodingFailed:
            return "Could not decode file content"
        }
    }
}
