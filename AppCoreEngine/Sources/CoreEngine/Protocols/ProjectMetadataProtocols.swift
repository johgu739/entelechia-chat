import Foundation

/// Shapes project metadata (bookmarks, selections) in a UI-free manner.
public protocol ProjectMetadataHandling: Sendable {
    func metadata(for bookmarkData: Data?, lastSelection: String?, isLastOpened: Bool) -> [String: String]
    func bookmarkData(from metadata: [String: String]) -> Data?
    func withMetadata(_ metadata: [String: String], appliedTo representation: ProjectRepresentation) -> ProjectRepresentation
}

