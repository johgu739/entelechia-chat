/// Base typed errors for the Engine. Extend with specific cases as modules are migrated.
public enum EngineError: Error, Sendable {
    case notImplemented
    case emptyMessage
    case streamingTransport(StreamTransportError)
    case persistenceFailed(underlying: String)
    case workspaceNotOpened
    case invalidSelection(String)
    case invalidWorkspace(String)
    case invalidDescriptor(String)
    case contextLoadFailed(String)
    case contextRequired(String)
    case conversationNotFound(String)
}

