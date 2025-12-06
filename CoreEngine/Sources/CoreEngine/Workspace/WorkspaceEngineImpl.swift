import Foundation

/// Workspace engine using FileDescriptor + FileID only.
public final class WorkspaceEngineImpl<PrefDriver: PreferencesDriver, CtxDriver: ContextPreferencesDriver>: WorkspaceEngine, @unchecked Sendable
where PrefDriver.Preferences == WorkspacePreferences,
      CtxDriver.ContextPreferences == WorkspaceContextPreferencesState {

    private let fileSystem: FileSystemAccess
    private let preferencesDriver: PrefDriver
    private let contextPreferencesDriver: CtxDriver
    private var currentState = WorkspaceState()
    private var descriptorIndex: [FileID: FileDescriptor] = [:]
    private var pathIndex: [String: FileID] = [:]

    public init(fileSystem: FileSystemAccess, preferences: PrefDriver, contextPreferences: CtxDriver) {
        self.fileSystem = fileSystem
        self.preferencesDriver = preferences
        self.contextPreferencesDriver = contextPreferences
    }

    public func openWorkspace(rootPath: String) async throws -> WorkspaceState {
        guard !rootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EngineError.invalidWorkspace("Empty root path")
        }
        let rootID = try fileSystem.resolveRoot(at: rootPath)
        currentState.rootPath = rootPath
        currentState.selectedPath = nil
        currentState.expandedIDs = []
        currentState.lastPersistedSelection = nil
        currentState.contextPreferences = .empty
        try await refreshTree(from: rootID, path: rootPath)

        // Load persisted preferences
        let prefs = (try? preferencesDriver.loadPreferences(for: URL(fileURLWithPath: rootPath))) ?? .empty
        if let last = prefs.lastSelectionPath, pathIndex.keys.contains(last) {
            currentState.selectedPath = last
            currentState.lastPersistedSelection = last
        }
        let ctx = (try? contextPreferencesDriver.loadContextPreferences(for: URL(fileURLWithPath: rootPath))) ?? .empty
        currentState.contextPreferences = ctx

        return currentState
    }

    public func state() -> WorkspaceState {
        currentState
    }

    public func descriptors() -> [FileDescriptor] {
        Array(descriptorIndex.values)
    }

    public func refresh() async throws -> [FileDescriptor] {
        guard let rootPath = currentState.rootPath else {
            throw EngineError.workspaceNotOpened
        }
        let rootID = try fileSystem.resolveRoot(at: rootPath)
        try await refreshTree(from: rootID, path: rootPath)
        normalizeSelectionAfterRefresh()
        return descriptors()
    }

    public func select(path: String?) async throws -> WorkspaceState {
        guard let rootPath = currentState.rootPath else {
            throw EngineError.workspaceNotOpened
        }

        guard let path else {
            currentState.selectedPath = nil
            return currentState
        }

        // Normalize paths relative to root
        let normalized = (path as NSString).standardizingPath
        guard pathIndex.keys.contains(normalized) else {
            throw EngineError.invalidSelection(path)
        }

        currentState.selectedPath = normalized
        currentState.lastPersistedSelection = normalized
        try? preferencesDriver.savePreferences(
            WorkspacePreferences(lastSelectionPath: normalized),
            for: URL(fileURLWithPath: rootPath)
        )
        return currentState
    }

    public func contextPreferences() async throws -> WorkspaceContextPreferencesState {
        guard let root = currentState.rootPath else { throw EngineError.workspaceNotOpened }
        let ctx = (try? contextPreferencesDriver.loadContextPreferences(for: URL(fileURLWithPath: root))) ?? .empty
        currentState.contextPreferences = ctx
        return ctx
    }

    public func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceContextPreferencesState {
        guard let root = currentState.rootPath else { throw EngineError.workspaceNotOpened }
        var prefs = (try? contextPreferencesDriver.loadContextPreferences(for: URL(fileURLWithPath: root))) ?? .empty
        if included {
            prefs.includedPaths.insert(path)
            prefs.excludedPaths.remove(path)
            prefs.lastFocusedFilePath = path
        } else {
            prefs.includedPaths.remove(path)
            prefs.excludedPaths.insert(path)
            prefs.lastFocusedFilePath = path

            // Drop selection if it was excluded
            if currentState.selectedPath == path {
                currentState.selectedPath = nil
                currentState.lastPersistedSelection = nil
                try? preferencesDriver.savePreferences(.empty, for: URL(fileURLWithPath: root))
            }
        }
        try contextPreferencesDriver.saveContextPreferences(prefs, for: URL(fileURLWithPath: root))
        currentState.contextPreferences = prefs
        return prefs
    }

    // MARK: - Internal

    private func refreshTree(from id: FileID, path: String) async throws {
        descriptorIndex.removeAll()
        pathIndex.removeAll()
        try walk(id: id, path: path)
    }

    private func normalizeSelectionAfterRefresh() {
        guard let selected = currentState.selectedPath else { return }
        // Clear selection if no longer present (e.g., excluded or missing)
        if !pathIndex.keys.contains(selected) {
            currentState.selectedPath = nil
            currentState.lastPersistedSelection = nil
            if let root = currentState.rootPath {
                try? preferencesDriver.savePreferences(.empty, for: URL(fileURLWithPath: root))
            }
        }
    }

    private func walk(id: FileID, path: String) throws {
        let children = try fileSystem.listChildren(of: id)
        descriptorIndex[id] = FileDescriptor(id: id, name: (path as NSString).lastPathComponent, type: .directory, children: filtered(children, at: path).map { $0.id })
        pathIndex[path] = id

        for child in filtered(children, at: path) {
            let childPath = (path as NSString).appendingPathComponent(child.name)
            descriptorIndex[child.id] = child
            pathIndex[childPath] = child.id
            if child.type == .directory {
                try walk(id: child.id, path: childPath)
            }
        }
    }

    // Apply context preferences filtering (exclude paths marked excluded).
    private func filtered(_ children: [FileDescriptor], at parentPath: String) -> [FileDescriptor] {
        guard !currentState.contextPreferences.excludedPaths.isEmpty else { return children }
        return children.filter { child in
            let fullPath = (parentPath as NSString).appendingPathComponent(child.name)
            return !currentState.contextPreferences.excludedPaths.contains(fullPath)
        }
    }
}

