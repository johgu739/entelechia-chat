// @EntelechiaHeaderStart
// Signifier: FileMetadataViewModel
// Substance: File metadata UI faculty
// Genus: Application faculty
// Differentia: Derives and presents metadata
// Form: Metadata derivation rules
// Matter: File properties
// Powers: Present metadata to inspector
// FinalCause: Inform user about file attributes
// Relations: Serves ContextInspector; depends on file models
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import Engine

@MainActor
class FileMetadataViewModel: ObservableObject {
    // LRU cache with max size to prevent memory leaks
    private struct CacheEntry<T> {
        let value: T
        let timestamp: Date
    }
    
    private var cachedLineCounts: [URL: CacheEntry<Int>] = [:]
    private var cachedFolderStats: [URL: CacheEntry<FolderStats>] = [:]
    
    private let maxCacheSize = 100
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    
    struct FolderStats {
        let totalFiles: Int
        let totalFolders: Int
        let totalSize: Int64
        let totalLines: Int
        let totalTokens: Int
    }
    
    func lineCount(for url: URL) async -> Int? {
        // Check cache first
        if let cached = cachedLineCounts[url],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.value
        }
        
        // Only count lines for text files
        guard let fileType = UTType(filenameExtension: url.pathExtension),
              fileType.conforms(to: .text) || fileType.conforms(to: .sourceCode) else {
            return nil
        }
        
        do {
            let content = try await loadFileContentSafely(at: url)
            let count = content.components(separatedBy: .newlines).count
            
            // Update cache with LRU eviction
            updateCache(key: url, value: count, cache: &cachedLineCounts)
            
            return count
        } catch {
            // Log error but don't crash
            print("Failed to count lines for \(url.path): \(error.localizedDescription)")
            return nil
        }
    }
    
    func folderStats(for url: URL) async -> FolderStats? {
        // Check cache first
        if let cached = cachedFolderStats[url],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.value
        }
        
        do {
            let stats = try await collectStats(from: url)
            
            // Update cache with LRU eviction
            updateCache(key: url, value: stats, cache: &cachedFolderStats)
            
            return stats
        } catch {
            print("Failed to collect folder stats for \(url.path): \(error.localizedDescription)")
            return nil
        }
    }
    
    private func collectStats(from directoryURL: URL) async throws -> FolderStats {
        var totalFiles = 0
        var totalFolders = 0
        var totalSize: Int64 = 0
        var totalLines = 0
        
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentTypeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw FileSystemError.cannotEnumerateDirectory
        }
        
        // Collect URLs first, then iterate (avoids async iteration issue)
        let urls = enumerator.compactMap { $0 as? URL }
        
        for fileURL in urls {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentTypeKey])
            let isDirectory = resourceValues.isDirectory == true
            
            if isDirectory {
                totalFolders += 1
            } else {
                totalFiles += 1
                if let size = resourceValues.fileSize {
                    totalSize += Int64(size)
                }
                
                // Count lines for text files only
                if let contentType = resourceValues.contentType,
                   contentType.conforms(to: .sourceCode) || contentType.conforms(to: .text) {
                    if let content = try? await loadFileContentSafely(at: fileURL) {
                        totalLines += content.components(separatedBy: .newlines).count
                    }
                }
            }
        }
        
        return FolderStats(
            totalFiles: totalFiles,
            totalFolders: totalFolders,
            totalSize: totalSize,
            totalLines: totalLines,
            totalTokens: TokenEstimator.estimateTokens(forByteCount: Int(totalSize))
        )
    }
    
    private func loadFileContentSafely(at url: URL) async throws -> String {
        return try await Task.detached(priority: .utility) {
            // Check file type before reading
            let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
            guard let contentType = resourceValues.contentType else {
                throw FileSystemError.unknownContentType
            }
            
            guard contentType.conforms(to: .text) || contentType.conforms(to: .sourceCode) else {
                throw FileSystemError.notATextFile
            }
            
            // Try UTF-8 first
            if let data = try? Data(contentsOf: url),
               let content = String(data: data, encoding: .utf8) {
                return content
            }
            
            // Fallback to system encoding
            return try String(contentsOf: url, encoding: .utf8)
        }.value
    }
    
    private func updateCache<T>(key: URL, value: T, cache: inout [URL: CacheEntry<T>]) {
        // Remove oldest entries if cache is full
        if cache.count >= maxCacheSize {
            let sortedEntries = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let entriesToRemove = sortedEntries.prefix(cache.count - maxCacheSize + 1)
            for (key, _) in entriesToRemove {
                cache.removeValue(forKey: key)
            }
        }
        
        cache[key] = CacheEntry(value: value, timestamp: Date())
    }
    
    func clearCache() {
        cachedLineCounts.removeAll()
        cachedFolderStats.removeAll()
    }
    
    enum FileSystemError: LocalizedError {
        case cannotEnumerateDirectory
        case unknownContentType
        case notATextFile
        
        var errorDescription: String? {
            switch self {
            case .cannotEnumerateDirectory:
                return "Cannot enumerate directory"
            case .unknownContentType:
                return "Unknown content type"
            case .notATextFile:
                return "Not a text file"
            }
        }
    }
}
