import Foundation

/// Pure workspace state for Engine.
public struct WorkspaceState: Codable, Sendable, Equatable {
    public var rootPath: String?
    public var selectedPath: String?
    public var expandedIDs: Set<FileID>
    public var lastPersistedSelection: String?
    public var contextPreferences: WorkspaceContextPreferencesState

    public init(
        rootPath: String? = nil,
        selectedPath: String? = nil,
        expandedIDs: Set<FileID> = [],
        lastPersistedSelection: String? = nil,
        contextPreferences: WorkspaceContextPreferencesState = .empty
    ) {
        self.rootPath = rootPath
        self.selectedPath = selectedPath
        self.expandedIDs = expandedIDs
        self.lastPersistedSelection = lastPersistedSelection
        self.contextPreferences = contextPreferences
    }
}

