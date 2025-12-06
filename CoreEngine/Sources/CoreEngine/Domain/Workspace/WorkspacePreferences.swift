import Foundation

/// Persisted workspace preferences (Engine-owned; UI-agnostic).
public struct WorkspacePreferences: Codable, Equatable, Sendable {
    public var lastSelectionPath: String?

    public static let empty = WorkspacePreferences(lastSelectionPath: nil)

    public init(lastSelectionPath: String? = nil) {
        self.lastSelectionPath = lastSelectionPath
    }
}

/// Persisted context preferences for workspace (Engine-owned; UI-agnostic).
public struct WorkspaceContextPreferencesState: Codable, Equatable, Sendable {
    public var includedPaths: Set<String>
    public var excludedPaths: Set<String>
    public var lastFocusedFilePath: String?

    public static let empty = WorkspaceContextPreferencesState(
        includedPaths: [],
        excludedPaths: [],
        lastFocusedFilePath: nil
    )

    public init(
        includedPaths: Set<String>,
        excludedPaths: Set<String>,
        lastFocusedFilePath: String? = nil
    ) {
        self.includedPaths = includedPaths
        self.excludedPaths = excludedPaths
        self.lastFocusedFilePath = lastFocusedFilePath
    }
}

