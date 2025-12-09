import Foundation
import AppCoreEngine

/// UI-ready representation of the workspace tree and selection.
public struct WorkspaceViewState: Sendable {
    public let rootPath: String?
    public let selectedDescriptorID: FileID?
    public let selectedPath: String?
    public let projection: WorkspaceTreeProjection?
    public let contextInclusions: [FileID: ContextInclusionState]
    public let watcherError: String?

    public init(
        rootPath: String?,
        selectedDescriptorID: FileID?,
        selectedPath: String?,
        projection: WorkspaceTreeProjection?,
        contextInclusions: [FileID: ContextInclusionState],
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

public enum WorkspaceErrorNotice: Sendable {
    case watcherUnavailable
    case refreshFailed(String)
}

public enum WorkspaceViewStateMapper {
    public static func map(
        update: WorkspaceUpdate,
        watcherError: WorkspaceErrorNotice?
    ) -> WorkspaceViewState {
        WorkspaceViewState(
            rootPath: update.snapshot.rootPath,
            selectedDescriptorID: update.snapshot.selectedDescriptorID,
            selectedPath: update.snapshot.selectedPath,
            projection: update.projection,
            contextInclusions: update.snapshot.contextInclusions,
            watcherError: watcherError.map { notice in
                switch notice {
                case .watcherUnavailable: return "Workspace watcher stopped (root missing or inaccessible)."
                case .refreshFailed(let message): return "Workspace refresh failed: \(message)"
                }
            }
        )
    }
}

public extension WorkspaceTreeProjection {
    var flattenedPaths: [FileID: String] {
        var result: [FileID: String] = [:]
        func walk(_ node: WorkspaceTreeProjection) {
            result[node.id] = node.path
            node.children.forEach { walk($0) }
        }
        walk(self)
        return result
    }
}

