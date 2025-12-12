import Foundation

/// Recent project representation.
public struct RecentProject: Equatable, Sendable {
    public let representation: UIProjectRepresentation
    public let bookmarkData: Data?
    
    public init(representation: UIProjectRepresentation, bookmarkData: Data?) {
        self.representation = representation
        self.bookmarkData = bookmarkData
    }
}

