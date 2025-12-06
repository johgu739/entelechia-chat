import Foundation

/// Security scope handling (macOS adapters implement; Engine uses protocol only).
public protocol SecurityScopeHandling: Sendable {
    func createBookmark(for url: URL) throws -> Data
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

