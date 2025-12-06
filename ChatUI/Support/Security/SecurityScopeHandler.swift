import Foundation

protocol SecurityScopeHandling {
    func makeBookmark(for url: URL) throws -> Data
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

/// Real implementation using security-scoped bookmarks and access.
struct RealSecurityScopeHandler: SecurityScopeHandling {
    func makeBookmark(for url: URL) throws -> Data {
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
    
    func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }
    
    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

