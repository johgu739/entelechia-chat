import Foundation

/// UI mirror of ProjectRepresentation.
public struct UIProjectRepresentation: Sendable, Equatable {
    public let rootPath: String
    public let name: String
    public let metadata: [String: String]
    public let linkedFiles: [String]
    
    public init(
        rootPath: String,
        name: String,
        metadata: [String: String] = [:],
        linkedFiles: [String] = []
    ) {
        self.rootPath = rootPath
        self.name = name
        self.metadata = metadata
        self.linkedFiles = linkedFiles
    }
}


