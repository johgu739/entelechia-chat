import Foundation
import CoreEngine

/// No-op security scope handler placeholder.
public struct NoopSecurityScopeHandler: SecurityScopeHandling {
    public init() {}

    public func createBookmark(for url: URL) throws -> Data { Data() }
    public func resolveBookmark(_ data: Data) throws -> URL { URL(fileURLWithPath: "/") }
    public func startAccessing(_ url: URL) -> Bool { true }
    public func stopAccessing(_ url: URL) {}
}

