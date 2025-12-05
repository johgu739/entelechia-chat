// @EntelechiaHeaderStart
// Substance: File persistence instrument
// Genus: Disk IO helper
// Differentia: Atomic read/write of JSON files
// Form: Directory assurance and file IO rules
// Matter: JSON data on disk
// Powers: Ensure directories; load; save; delete files
// FinalCause: Store domain records reliably
// Relations: Serves ConversationStore and ProjectStore
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation

/// Low-level file read/write abstraction with atomic writes and defensive error handling
final class FileStore {
    static let shared = FileStore()
    
    private init() {}
    
    /// Resolve the base database directory
    func resolveDatabasePath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Entelechia", isDirectory: true)
    }
    
    /// Resolve conversations directory
    func resolveConversationsDirectory() -> URL {
        resolveDatabasePath().appendingPathComponent("Conversations", isDirectory: true)
    }
    
    /// Resolve index file path
    func resolveIndexPath() -> URL {
        resolveDatabasePath().appendingPathComponent("index.json", isDirectory: false)
    }
    
    /// Ensure all required directories exist
    /// Throws if directory creation fails
    func ensureDirectoryExists() throws {
        let conversationsDir = resolveConversationsDirectory()
        try FileManager.default.createDirectory(at: conversationsDir, withIntermediateDirectories: true)
    }
    
    /// Load a Codable type from a URL
    /// Returns nil if file doesn't exist
    /// Throws if file exists but decode fails (corrupted data)
    func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // If decode fails, file is corrupted - throw error, don't hide it
        return try decoder.decode(type, from: data)
    }
    
    /// Save an Encodable type to a URL with atomic write
    func save<T: Encodable>(_ value: T, to url: URL) throws {
        // Ensure parent directory exists
        let parentDir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(value)
        
        // Atomic write
        try data.write(to: url, options: .atomic)
    }
    
    /// Delete a file if it exists
    func delete(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    /// Check if a file exists
    func exists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    
    /// List all JSON files in conversations directory
    /// Throws if directory listing fails
    func listConversationFiles() throws -> [URL] {
        let conversationsDir = resolveConversationsDirectory()
        // If directory doesn't exist, return empty array (OK)
        guard FileManager.default.fileExists(atPath: conversationsDir.path) else {
            return []
        }
        
        // If listing fails, throw - no silent errors
        let files = try FileManager.default.contentsOfDirectory(
            at: conversationsDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        return files.filter { $0.pathExtension == "json" }
    }
}
