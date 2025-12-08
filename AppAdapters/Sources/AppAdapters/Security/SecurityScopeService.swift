import Foundation
import CoreEngine

/// Thread-safe security scope service that creates, resolves, and manages security-scoped bookmarks.
///
/// Concurrency: protected by NSLock; bookmark APIs are synchronous. Marked `@unchecked Sendable` because
/// NSLock is not statically Sendable.
///
/// Lifecycle contract:
/// - `createBookmark(for:)` requires a valid URL and returns a security-scoped bookmark Data.
/// - `resolveBookmark(_:)` expects bookmark Data produced by `createBookmark`; throws on stale/invalid data.
/// - `startAccessing(_:)` must be paired with `stopAccessing(_:)`; callers must stop for any started URL.
/// - Errors from bookmark APIs are surfaced to callers; no silent recovery is attempted.
public final class SecurityScopeService: SecurityScopeHandling, @unchecked Sendable {
    private let lock = NSLock()

    public init() {}

    public func createBookmark(for url: URL) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
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

    public func resolveBookmark(_ data: Data) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            throw NSError(domain: "SecurityScope", code: -1, userInfo: [NSLocalizedDescriptionKey: "Stale bookmark"])
        }
        return url
    }

    public func startAccessing(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return url.startAccessingSecurityScopedResource()
    }

    public func stopAccessing(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        url.stopAccessingSecurityScopedResource()
    }
}

