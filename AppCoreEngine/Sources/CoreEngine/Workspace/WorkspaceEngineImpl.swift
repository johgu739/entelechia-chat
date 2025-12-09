import Foundation

/// Workspace engine using FileDescriptor + FileID only.
///
/// Invariants (concurrency & behavior):
/// - Update stream continuation is owned by a private actor (`UpdateStreamBox`); only that actor touches it,
///   guaranteeing a single executor for yields/finish.
/// - State mutation lives inside `WorkspaceStateActor`; non-actor fields are read-only after init.
/// - Selection operations require the path to exist in `pathIndex`; missing paths throw `invalidSelection`.
/// - Context inclusions derive from stored preferences; exclusions remove selection and persist resets.
/// - Watcher termination yields `watcherUnavailable`; refresh failures surface as `refreshFailed` in updates.
public final class WorkspaceEngineImpl<PrefDriver: PreferencesDriver, CtxDriver: ContextPreferencesDriver>: WorkspaceEngine, Sendable
where PrefDriver.Preferences == WorkspacePreferences,
      CtxDriver.ContextPreferences == WorkspaceContextPreferencesState {

    private let fileSystem: FileSystemAccess
    private let preferencesDriver: PrefDriver
    private let contextPreferencesDriver: CtxDriver
    private let watcher: FileSystemWatching
    private let state = WorkspaceStateActor()
    private let updateStreamBox = UpdateStreamBox()

    public init(fileSystem: FileSystemAccess, preferences: PrefDriver, contextPreferences: CtxDriver, watcher: FileSystemWatching) {
        self.fileSystem = fileSystem
        self.preferencesDriver = preferences
        self.contextPreferencesDriver = contextPreferences
        self.watcher = watcher
    }

    public func openWorkspace(rootPath: String) async throws -> WorkspaceSnapshot {
        guard !rootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EngineError.invalidWorkspace("Empty root path")
        }
        let canonicalRoot = URL(fileURLWithPath: rootPath).resolvingSymlinksInPath().standardizedFileURL.path
        let rootURL = URL(fileURLWithPath: canonicalRoot)
        let contextPrefs = (try? contextPreferencesDriver.loadContextPreferences(for: rootURL)) ?? .empty

        let rootID = try fileSystem.resolveRoot(at: canonicalRoot)
        let tree = try buildTree(from: rootID, path: canonicalRoot, contextPreferences: contextPrefs)

        let prefs = (try? preferencesDriver.loadPreferences(for: rootURL)) ?? .empty
        let persistedSelection: String?
        if let last = prefs.lastSelectionPath, tree.pathIndex.keys.contains(last) {
            persistedSelection = last
        } else {
            persistedSelection = nil
        }

        let snapshot = buildSnapshot(
            rootPath: rootPath,
            selectedPath: persistedSelection,
            lastPersistedSelection: persistedSelection,
            contextPreferences: contextPrefs,
            descriptorIndex: tree.descriptorIndex,
            pathIndex: tree.pathIndex
        )

        await state.replace(snapshot: snapshot, descriptorIndex: tree.descriptorIndex, pathIndex: tree.pathIndex)
        await emitUpdate(snapshot: snapshot)
        await startWatcher(rootPath: rootPath)
        return snapshot
    }

    public func snapshot() async -> WorkspaceSnapshot {
        await state.snapshotValue()
    }

    public func refresh() async throws -> WorkspaceSnapshot {
        try Task.checkCancellation()
        let initial = await state.current()
        guard let rootPath = initial.snapshot.rootPath else {
            throw EngineError.workspaceNotOpened
        }
        try Task.checkCancellation()
        let rootURL = URL(fileURLWithPath: rootPath)
        let persistedPrefs = (try? contextPreferencesDriver.loadContextPreferences(for: rootURL)) ?? initial.snapshot.contextPreferences
        let contextPrefs = mergeContextPreferences(persistedPrefs, initial.snapshot.contextPreferences)
        let rootID = try fileSystem.resolveRoot(at: rootPath)
        try Task.checkCancellation()
        let tree = try buildTree(from: rootID, path: rootPath, contextPreferences: contextPrefs)

        // Re-read state and persisted preferences in case another task (e.g., setContextInclusion)
        // mutated context preferences while this refresh was in-flight.
        let latest = await state.current()
        let latestPersistedPrefs = (try? contextPreferencesDriver.loadContextPreferences(for: rootURL)) ?? persistedPrefs
        let mergedContextPrefs = mergeContextPreferences(latestPersistedPrefs, latest.snapshot.contextPreferences)

        var selectedPath = latest.snapshot.selectedPath
        var lastPersistedSelection = latest.snapshot.lastPersistedSelection
        if let selected = selectedPath, !tree.pathIndex.keys.contains(selected) {
            selectedPath = nil
            lastPersistedSelection = nil
            try? preferencesDriver.savePreferences(.empty, for: URL(fileURLWithPath: rootPath))
        }

        let snapshot = buildSnapshot(
            rootPath: rootPath,
            selectedPath: selectedPath,
            lastPersistedSelection: lastPersistedSelection,
            contextPreferences: mergedContextPrefs,
            descriptorIndex: tree.descriptorIndex,
            pathIndex: tree.pathIndex
        )
        await state.replace(snapshot: snapshot, descriptorIndex: tree.descriptorIndex, pathIndex: tree.pathIndex)
        await emitUpdate(snapshot: snapshot)
        return snapshot
    }

    public func select(path: String?) async throws -> WorkspaceSnapshot {
        let current = await state.current()
        guard let rootPath = current.snapshot.rootPath else {
            throw EngineError.workspaceNotOpened
        }

        let descriptorIndex = current.descriptorIndex
        let pathIndex = current.pathIndex

        if path == nil {
            let snapshot = buildSnapshot(
                rootPath: rootPath,
                selectedPath: nil,
                lastPersistedSelection: nil,
                contextPreferences: current.snapshot.contextPreferences,
                descriptorIndex: descriptorIndex,
                pathIndex: pathIndex
            )
            await state.replace(snapshot: snapshot, descriptorIndex: descriptorIndex, pathIndex: pathIndex)
            return snapshot
        }

        guard let path else { throw EngineError.invalidSelection("Nil path") }
        let normalized = (path as NSString).standardizingPath
        guard pathIndex.keys.contains(normalized) else {
            throw EngineError.invalidSelection(path)
        }

        let snapshot = buildSnapshot(
            rootPath: rootPath,
            selectedPath: normalized,
            lastPersistedSelection: normalized,
            contextPreferences: current.snapshot.contextPreferences,
            descriptorIndex: descriptorIndex,
            pathIndex: pathIndex
        )
        try? preferencesDriver.savePreferences(
            WorkspacePreferences(lastSelectionPath: normalized),
            for: URL(fileURLWithPath: rootPath)
        )
        await state.replace(snapshot: snapshot, descriptorIndex: descriptorIndex, pathIndex: pathIndex)
        await emitUpdate(snapshot: snapshot)
        return snapshot
    }

    public func contextPreferences() async throws -> WorkspaceSnapshot {
        let current = await state.current()
        guard let root = current.snapshot.rootPath else { throw EngineError.workspaceNotOpened }
        let persisted = (try? contextPreferencesDriver.loadContextPreferences(for: URL(fileURLWithPath: root))) ?? .empty
        let ctx = mergeContextPreferences(persisted, current.snapshot.contextPreferences)
        let snapshot = buildSnapshot(
            rootPath: root,
            selectedPath: current.snapshot.selectedPath,
            lastPersistedSelection: current.snapshot.lastPersistedSelection,
            contextPreferences: ctx,
            descriptorIndex: current.descriptorIndex,
            pathIndex: current.pathIndex
        )
        await state.replace(snapshot: snapshot, descriptorIndex: current.descriptorIndex, pathIndex: current.pathIndex)
        await emitUpdate(snapshot: snapshot)
        return snapshot
    }

    public func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot {
        let current = await state.current()
        guard let root = current.snapshot.rootPath else { throw EngineError.workspaceNotOpened }
        let rootURL = URL(fileURLWithPath: root)
        var prefs = (try? contextPreferencesDriver.loadContextPreferences(for: rootURL)) ?? .empty
        prefs = mergeContextPreferences(prefs, current.snapshot.contextPreferences)

        var selectedPath = current.snapshot.selectedPath
        var lastPersisted = current.snapshot.lastPersistedSelection

        if included {
            prefs.includedPaths.insert(path)
            prefs.excludedPaths.remove(path)
            prefs.lastFocusedFilePath = path
        } else {
            prefs.includedPaths.remove(path)
            prefs.excludedPaths.insert(path)
            prefs.lastFocusedFilePath = path

            if selectedPath == path {
                selectedPath = nil
                lastPersisted = nil
                try? preferencesDriver.savePreferences(.empty, for: rootURL)
            }
        }
        try contextPreferencesDriver.saveContextPreferences(prefs, for: rootURL)
        let snapshot = buildSnapshot(
            rootPath: root,
            selectedPath: selectedPath,
            lastPersistedSelection: lastPersisted,
            contextPreferences: prefs,
            descriptorIndex: current.descriptorIndex,
            pathIndex: current.pathIndex
        )
        await state.replace(snapshot: snapshot, descriptorIndex: current.descriptorIndex, pathIndex: current.pathIndex)
        await emitUpdate(snapshot: snapshot)
        return snapshot
    }

    public func treeProjection() async -> WorkspaceTreeProjection? {
        let current = await state.current()
        guard let rootPath = current.snapshot.rootPath,
              let rootID = current.pathIndex[rootPath] else { return nil }
        let descriptorPaths = Dictionary(uniqueKeysWithValues: current.pathIndex.map { ($0.value, $0.key) })
        return buildProjection(
            id: rootID,
            descriptorIndex: current.descriptorIndex,
            descriptorPaths: descriptorPaths
        )
    }

    public func updates() -> AsyncStream<WorkspaceUpdate> {
        updateStreamBox.stream
    }

    private func mergeContextPreferences(
        _ persisted: WorkspaceContextPreferencesState,
        _ current: WorkspaceContextPreferencesState
    ) -> WorkspaceContextPreferencesState {
        var merged = persisted
        merged.includedPaths.formUnion(current.includedPaths)
        merged.excludedPaths.formUnion(current.excludedPaths)
        if merged.lastFocusedFilePath == nil {
            merged.lastFocusedFilePath = current.lastFocusedFilePath
        }
        return merged
    }

    /// Cancels watcher and closes update stream; call in teardown to avoid dangling tasks.
    public func shutdown() async {
        await state.cancelWatcher()
        await updateStreamBox.finish()
    }

    // MARK: - Internal

    private func buildTree(
        from id: FileID,
        path: String,
        contextPreferences: WorkspaceContextPreferencesState
    ) throws -> WorkspaceTree {
        if Task.isCancelled { throw CancellationError() }
        var descriptorIndex: [FileID: FileDescriptor] = [:]
        var pathIndex: [String: FileID] = [:]
        try walk(
            id: id,
            path: path,
            contextPreferences: contextPreferences,
            descriptorIndex: &descriptorIndex,
            pathIndex: &pathIndex
        )
        return WorkspaceTree(descriptorIndex: descriptorIndex, pathIndex: pathIndex)
    }

    private func walk(
        id: FileID,
        path: String,
        contextPreferences: WorkspaceContextPreferencesState,
        descriptorIndex: inout [FileID: FileDescriptor],
        pathIndex: inout [String: FileID]
    ) throws {
        if Task.isCancelled { throw CancellationError() }
        let children = try fileSystem.listChildren(of: id)
        if Task.isCancelled { throw CancellationError() }
        let filteredChildren = filtered(children, preferences: contextPreferences)
            .sorted { $0.canonicalPath.localizedCaseInsensitiveCompare($1.canonicalPath) == .orderedAscending }
        descriptorIndex[id] = FileDescriptor(
            id: id,
            name: (path as NSString).lastPathComponent,
            type: .directory,
            children: filteredChildren.map { $0.id },
            canonicalPath: path,
            language: nil,
            size: 0,
            hash: ""
        )
        pathIndex[path] = id

        for child in filteredChildren {
            let childPath = child.canonicalPath
            descriptorIndex[child.id] = child
            pathIndex[childPath] = child.id
            if child.type == .directory {
                try walk(
                    id: child.id,
                    path: childPath,
                    contextPreferences: contextPreferences,
                    descriptorIndex: &descriptorIndex,
                    pathIndex: &pathIndex
                )
            }
            if Task.isCancelled { throw CancellationError() }
        }
    }

    private func filtered(_ children: [FileDescriptor], preferences: WorkspaceContextPreferencesState) -> [FileDescriptor] {
        guard !preferences.excludedPaths.isEmpty else { return children }
        return children.filter { child in
            !preferences.excludedPaths.contains(child.canonicalPath)
        }
    }

    private func buildContextInclusions(for prefs: WorkspaceContextPreferencesState, pathIndex: [String: FileID]) -> [FileID: ContextInclusionState] {
        let descriptorPaths = Dictionary(uniqueKeysWithValues: pathIndex.map { ($0.value, $0.key) })
        var result: [FileID: ContextInclusionState] = [:]
        for (id, path) in descriptorPaths.sorted(by: { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }) {
            if prefs.excludedPaths.contains(path) {
                result[id] = .excluded
                continue
            }
            if !prefs.includedPaths.isEmpty {
                result[id] = prefs.includedPaths.contains(path) ? .included : .excluded
                continue
            }
            result[id] = .neutral
        }
        return result
    }

    private func buildSnapshot(
        rootPath: String?,
        selectedPath: String?,
        lastPersistedSelection: String?,
        contextPreferences: WorkspaceContextPreferencesState,
        descriptorIndex: [FileID: FileDescriptor],
        pathIndex: [String: FileID]
    ) -> WorkspaceSnapshot {
        let descriptorPaths = Dictionary(uniqueKeysWithValues: pathIndex.map { ($0.value, $0.key) })
        let selectedDescriptorID = selectedPath.flatMap { pathIndex[$0] }
        let persistedDescriptorID = lastPersistedSelection.flatMap { pathIndex[$0] }
        let orderedDescriptors = descriptorIndex.values.sorted { lhs, rhs in
            let pathCompare = lhs.canonicalPath.localizedCaseInsensitiveCompare(rhs.canonicalPath)
            if pathCompare != .orderedSame { return pathCompare == .orderedAscending }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        let orderedContextInclusions = buildContextInclusions(for: contextPreferences, pathIndex: pathIndex)
        let snapshotHash = SnapshotHasher.hash(
            rootPath: rootPath,
            descriptors: orderedDescriptors,
            descriptorPaths: descriptorPaths,
            contextInclusions: orderedContextInclusions,
            contextPreferences: contextPreferences
        )
        return WorkspaceSnapshot(
            rootPath: rootPath,
            selectedPath: selectedPath,
            lastPersistedSelection: lastPersistedSelection,
            selectedDescriptorID: selectedDescriptorID,
            lastPersistedDescriptorID: persistedDescriptorID,
            contextPreferences: contextPreferences,
            descriptorPaths: descriptorPaths,
            contextInclusions: orderedContextInclusions,
            descriptors: orderedDescriptors,
            snapshotHash: snapshotHash
        )
    }

    private func buildProjection(
        id: FileID,
        descriptorIndex: [FileID: FileDescriptor],
        descriptorPaths: [FileID: String]
    ) -> WorkspaceTreeProjection? {
        guard let descriptor = descriptorIndex[id],
              let path = descriptorPaths[id] else { return nil }
        let children = descriptor.children
            .compactMap { buildProjection(id: $0, descriptorIndex: descriptorIndex, descriptorPaths: descriptorPaths) }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory && !rhs.isDirectory
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        return WorkspaceTreeProjection(
            id: descriptor.id,
            name: descriptor.name,
            path: path,
            isDirectory: descriptor.type == .directory,
            children: children
        )
    }

    private func projection(from snapshot: WorkspaceSnapshot) -> WorkspaceTreeProjection? {
        guard let _ = snapshot.rootPath else { return nil }
        var descriptorIndex: [FileID: FileDescriptor] = [:]
        var childIDs = Set<FileID>()
        for descriptor in snapshot.descriptors {
            descriptorIndex[descriptor.id] = descriptor
            childIDs.formUnion(descriptor.children)
        }
        guard let rootID = descriptorIndex.keys.first(where: { !childIDs.contains($0) }) else {
            return nil
        }
        return buildProjection(id: rootID, descriptorIndex: descriptorIndex, descriptorPaths: snapshot.descriptorPaths)
    }

    private func startWatcher(rootPath: String) async {
        await state.cancelWatcher()
        let task = Task { [weak self] in
            guard let self else { return }
            let stream = self.watcher.watch(rootPath: rootPath)
            for await _ in stream {
                if Task.isCancelled { break }
                do {
                    let snap = try await self.refresh()
                    await self.emitUpdate(snapshot: snap)
                } catch {
                    await self.emitUpdate(snapshot: await self.state.snapshotValue(), error: .refreshFailed(error.localizedDescription))
                }
            }
            // If stream ends (root removed or watcher unavailable), signal error.
            let currentSnapshot = await self.state.snapshotValue()
            await self.emitUpdate(snapshot: currentSnapshot, error: .watcherUnavailable)
        }
        await state.replaceWatcher(task: task)
    }

    private func emitUpdate(snapshot: WorkspaceSnapshot, error: WorkspaceUpdateError? = nil) async {
        let projection = projection(from: snapshot)
        await updateStreamBox.yield(WorkspaceUpdate(snapshot: snapshot, projection: projection, error: error))
    }
}

private struct WorkspaceTree {
    let descriptorIndex: [FileID: FileDescriptor]
    let pathIndex: [String: FileID]
}

private enum SnapshotHasher {
    static func hash(
        rootPath: String?,
        descriptors: [FileDescriptor],
        descriptorPaths: [FileID: String],
        contextInclusions: [FileID: ContextInclusionState],
        contextPreferences: WorkspaceContextPreferencesState
    ) -> String {
        var lines: [String] = []
        lines.append("root:\(rootPath ?? "")")
        for (id, path) in descriptorPaths.sorted(by: { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }) {
            lines.append("p|\(id.rawValue.uuidString)|\(path)")
        }
        for descriptor in descriptors {
            let childIDs = descriptor.children.map { $0.rawValue.uuidString }.joined(separator: ",")
            lines.append("d|\(descriptor.canonicalPath)|\(descriptor.language ?? "")|\(descriptor.size)|\(descriptor.hash)|\(descriptor.type.rawValue)|\(childIDs)")
        }
        for (id, state) in contextInclusions.sorted(by: { $0.key.rawValue.uuidString < $1.key.rawValue.uuidString }) {
            lines.append("i|\(id.rawValue.uuidString)|\(state.rawValue)")
        }
        let included = contextPreferences.includedPaths.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }).joined(separator: "|")
        let excluded = contextPreferences.excludedPaths.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }).joined(separator: "|")
        lines.append("prefs|included|\(included)")
        lines.append("prefs|excluded|\(excluded)")
        if let focused = contextPreferences.lastFocusedFilePath {
            lines.append("prefs|focused|\(focused)")
        }
        let joined = lines.joined(separator: "\n")
        return StableHasher.sha256(data: Data(joined.utf8))
    }
}

private actor WorkspaceStateActor {
    private var snapshot: WorkspaceSnapshot
    private var descriptorIndex: [FileID: FileDescriptor]
    private var pathIndex: [String: FileID]
    private var watcherTask: Task<Void, Never>?

    init(
        snapshot: WorkspaceSnapshot = .empty,
        descriptorIndex: [FileID: FileDescriptor] = [:],
        pathIndex: [String: FileID] = [:]
    ) {
        self.snapshot = snapshot
        self.descriptorIndex = descriptorIndex
        self.pathIndex = pathIndex
    }

    func replace(snapshot: WorkspaceSnapshot, descriptorIndex: [FileID: FileDescriptor], pathIndex: [String: FileID]) {
        self.snapshot = snapshot
        self.descriptorIndex = descriptorIndex
        self.pathIndex = pathIndex
    }

    func snapshotValue() -> WorkspaceSnapshot {
        snapshot
    }

    func current() -> (snapshot: WorkspaceSnapshot, descriptorIndex: [FileID: FileDescriptor], pathIndex: [String: FileID]) {
        (snapshot, descriptorIndex, pathIndex)
    }

    func replaceWatcher(task: Task<Void, Never>?) {
        watcherTask?.cancel()
        watcherTask = task
    }

    func cancelWatcher() {
        watcherTask?.cancel()
        watcherTask = nil
    }
}
