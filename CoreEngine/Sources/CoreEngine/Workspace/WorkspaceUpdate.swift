import Foundation

public struct WorkspaceUpdate: Sendable {
    public let snapshot: WorkspaceSnapshot
    public let projection: WorkspaceTreeProjection?
    public let error: WorkspaceUpdateError?

    public init(snapshot: WorkspaceSnapshot, projection: WorkspaceTreeProjection?, error: WorkspaceUpdateError? = nil) {
        self.snapshot = snapshot
        self.projection = projection
        self.error = error
    }
}

public enum WorkspaceUpdateError: Sendable, Equatable {
    case watcherUnavailable
    case refreshFailed(String)
}

