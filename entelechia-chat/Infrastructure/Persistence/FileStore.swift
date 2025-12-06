// @EntelechiaHeaderStart
// Signifier: FileStore
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
import os.log

/// Low-level file read/write abstraction with atomic writes and defensive error handling
final class FileStore {
    private static var _shared = FileStore()
    static var shared: FileStore { _shared }
    
    private let logger = Logger.persistence
    private let baseURL: URL
    
    /// Configure the shared instance for tests with an explicit root path.
    /// This avoids ProcessInfo.environment snapshot issues.
    static func configureShared(forRoot root: URL) {
        _shared = FileStore(baseURL: root)
    }
    
    init(baseURL: URL? = nil) {
        if let baseURL = baseURL {
            self.baseURL = baseURL
        } else if let override = ProcessInfo.processInfo.environment["ENTELECHIA_APP_SUPPORT"] {
            self.baseURL = URL(fileURLWithPath: override, isDirectory: true)
                .appendingPathComponent("Entelechia", isDirectory: true)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseURL = appSupport.appendingPathComponent("Entelechia", isDirectory: true)
        }
    }
    
    /// Resolve the base database directory
    func resolveDatabasePath() -> URL {
        baseURL
    }
    
    /// Resolve conversations directory
    func resolveConversationsDirectory() -> URL {
        resolveDatabasePath().appendingPathComponent("Conversations", isDirectory: true)
    }
    
    /// Resolve canonical index file path (inside Conversations directory)
    func resolveIndexPath() -> URL {
        resolveConversationsDirectory().appendingPathComponent("index.json", isDirectory: false)
    }

    /// Resolve legacy index path (pre-migration location)
    func resolveLegacyIndexPath() -> URL {
        resolveDatabasePath().appendingPathComponent("index.json", isDirectory: false)
    }
    
    /// Ensure all required directories exist
    /// Throws if directory creation fails
    func ensureDirectoryExists() throws {
        let conversationsDir = resolveConversationsDirectory()
        do {
            try FileManager.default.createDirectory(at: conversationsDir, withIntermediateDirectories: true)
            logger.debug("Ensured conversations directory exists at \(conversationsDir.path, privacy: .private)")
        } catch {
            logger.error("Failed to create conversations directory at \(conversationsDir.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            throw error
        }
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
        logger.debug("Saved file at \(url.path, privacy: .private)")
    }
    
    /// Delete a file if it exists
    func delete(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
            logger.debug("Deleted file at \(url.path, privacy: .private)")
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
