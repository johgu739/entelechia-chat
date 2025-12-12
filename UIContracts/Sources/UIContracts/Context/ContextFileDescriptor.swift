import Foundation

public struct ContextFileDescriptor: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let path: String
    public let language: String?
    public let size: Int
    public let hash: String
    public let isIncluded: Bool
    public let isTruncated: Bool
    
    public init(
        id: UUID,
        path: String,
        language: String?,
        size: Int,
        hash: String,
        isIncluded: Bool,
        isTruncated: Bool
    ) {
        self.id = id
        self.path = path
        self.language = language
        self.size = size
        self.hash = hash
        self.isIncluded = isIncluded
        self.isTruncated = isTruncated
    }
}

