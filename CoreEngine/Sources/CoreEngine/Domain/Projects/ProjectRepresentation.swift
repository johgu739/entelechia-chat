import Foundation

/// Flat, pure project representation.
public struct ProjectRepresentation: Codable, Sendable, Equatable {
    public let rootPath: String
    public var name: String
    public var metadata: [String: String]
    public var linkedFiles: [String]

    public init(rootPath: String, name: String, metadata: [String: String] = [:], linkedFiles: [String] = []) {
        self.rootPath = rootPath
        self.name = name
        self.metadata = metadata
        self.linkedFiles = linkedFiles
    }
}

