import Foundation

/// File identifier (pure value type).
public struct FileID: Hashable, Codable, Sendable {
    public let rawValue: UUID
    
    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}


