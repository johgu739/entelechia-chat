import Foundation

/// UI-ready representation of the workspace tree and selection.
public struct WorkspaceViewState: Sendable, Equatable {
    public let rootPath: String?
    public let selectedDescriptorID: UUID?
    public let selectedPath: String?
    public let projection: UIWorkspaceTree?
    public let contextInclusions: [UUID: UIContextInclusionState]
    public let watcherError: String?

    public init(
        rootPath: String?,
        selectedDescriptorID: UUID?,
        selectedPath: String?,
        projection: UIWorkspaceTree?,
        contextInclusions: [UUID: UIContextInclusionState],
        watcherError: String?
    ) {
        self.rootPath = rootPath
        self.selectedDescriptorID = selectedDescriptorID
        self.selectedPath = selectedPath
        self.projection = projection
        self.contextInclusions = contextInclusions
        self.watcherError = watcherError
    }
}

