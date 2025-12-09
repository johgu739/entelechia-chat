import Foundation
import AppCoreEngine

/// Concrete metadata handler for projects (bookmark encoding/decoding).
public struct ProjectMetadataAdapter: ProjectMetadataHandling, Sendable {
    public init() {}

    public func metadata(for bookmarkData: Data?, lastSelection: String?, isLastOpened: Bool) -> [String: String] {
        var meta: [String: String] = [:]
        if let data = bookmarkData {
            meta["bookmarkData"] = data.base64EncodedString()
        }
        if let sel = lastSelection {
            meta["lastSelection"] = sel
        }
        if isLastOpened {
            meta["lastOpened"] = "true"
        }
        return meta
    }

    public func bookmarkData(from metadata: [String: String]) -> Data? {
        metadata["bookmarkData"].flatMap { Data(base64Encoded: $0) }
    }

    public func withMetadata(_ metadata: [String: String], appliedTo representation: ProjectRepresentation) -> ProjectRepresentation {
        var rep = representation
        rep.metadata = metadata
        return rep
    }
}

