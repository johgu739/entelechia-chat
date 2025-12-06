import Foundation

/// Workspace context preferences abstraction (host implements; Engine consumes).
public protocol WorkspaceContextPreferences: Sendable {
    var excludedPaths: Set<String> { get }
    var includedPaths: Set<String> { get }
    var lastFocusedFilePath: String? { get }
}

public protocol WorkspaceContextControlling: Sendable {
    func contextPreferences() async throws -> WorkspaceContextPreferencesState
    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceContextPreferencesState
}

