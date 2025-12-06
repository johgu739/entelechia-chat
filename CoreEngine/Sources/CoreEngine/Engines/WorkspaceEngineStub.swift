import Foundation

public final class WorkspaceEngineStub: WorkspaceEngine, @unchecked Sendable {
    private var workspaceState = WorkspaceState()
    private var descriptorsStore: [FileDescriptor] = []
    private var contextPrefs = WorkspaceContextPreferencesState.empty

    public init() {}

    public func openWorkspace(rootPath: String) async throws -> WorkspaceState {
        workspaceState.rootPath = rootPath
        workspaceState.selectedPath = nil
        workspaceState.expandedIDs = []
        descriptorsStore = []
        return workspaceState
    }

    public func state() -> WorkspaceState {
        workspaceState
    }

    public func descriptors() -> [FileDescriptor] {
        descriptorsStore
    }

    public func refresh() async throws -> [FileDescriptor] { descriptorsStore }

    public func select(path: String?) async throws -> WorkspaceState {
        workspaceState.selectedPath = path
        workspaceState.lastPersistedSelection = path
        return workspaceState
    }

    public func contextPreferences() async throws -> WorkspaceContextPreferencesState {
        contextPrefs
    }

    public func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceContextPreferencesState {
        if included {
            contextPrefs.includedPaths.insert(path)
            contextPrefs.excludedPaths.remove(path)
        } else {
            contextPrefs.includedPaths.remove(path)
            contextPrefs.excludedPaths.insert(path)
        }
        workspaceState.contextPreferences = contextPrefs
        return contextPrefs
    }
}

