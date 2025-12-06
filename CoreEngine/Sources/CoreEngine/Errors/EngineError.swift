/// Base typed errors for the Engine. Extend with specific cases as modules are migrated.
public enum EngineError: Error, Sendable {
    case notImplemented
    case emptyMessage
    case streamingFailed
    case persistenceFailed
    case workspaceNotOpened
    case invalidSelection(String)
    case invalidWorkspace(String)
}

