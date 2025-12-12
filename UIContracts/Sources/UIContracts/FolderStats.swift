import Foundation

/// Folder statistics for UI display (pure value type).
public struct FolderStats {
    public let totalFiles: Int
    public let totalFolders: Int
    public let totalSize: Int64
    public let totalLines: Int
    public let totalTokens: Int
    
    public init(
        totalFiles: Int,
        totalFolders: Int,
        totalSize: Int64,
        totalLines: Int,
        totalTokens: Int
    ) {
        self.totalFiles = totalFiles
        self.totalFolders = totalFolders
        self.totalSize = totalSize
        self.totalLines = totalLines
        self.totalTokens = totalTokens
    }
}

