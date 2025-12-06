import Foundation
import Engine

/// No-op security scope handler placeholder.
public struct NoopSecurityScopeHandler: SecurityScopeHandling {
    public init() {}

    public func createBookmark(for url: URL) throws -> Data { Data() }
    public func startAccessing(_ url: URL) -> Bool { true }
    public func stopAccessing(_ url: URL) {}
}

