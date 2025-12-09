import XCTest
@testable import AppCoreEngine

final class WorkspaceEngineImplTests: XCTestCase {
    private final class ResourceRegistry {
        private var engines: [WorkspaceEngineImpl<InMemoryWorkspacePrefs, InMemoryContextPrefs>] = []

        func register(_ engine: WorkspaceEngineImpl<InMemoryWorkspacePrefs, InMemoryContextPrefs>) {
            engines.append(engine)
        }

        func shutdownAll() async {
            for engine in engines {
                await engine.shutdown()
            }
            engines.removeAll()
        }

        var isEmpty: Bool { engines.isEmpty }
    }

    private var registry: ResourceRegistry!
    private var prefs: InMemoryWorkspacePrefs!
    private var ctxPrefs: InMemoryContextPrefs!

    override func setUp() async throws {
        try await super.setUp()
        registry = ResourceRegistry()
    }

    override func tearDown() async throws {
        await registry.shutdownAll()
        XCTAssertTrue(registry.isEmpty, "Registry not empty after shutdownAll")
        registry = nil
        try await super.tearDown()
    }

    func testOpenAndSelectValidPath() async throws {
        let fs = FakeFileSystem(tree: [
            "/root": ["src", "README.md"],
            "/root/src": ["main.swift"]
        ])
        let engine = makeEngine(fs: fs)

        _ = try await engine.openWorkspace(rootPath: "/root")
        _ = try await engine.refresh()

        let state = try await engine.select(path: "/root/src")
        XCTAssertEqual(state.selectedPath, "/root/src")
    }

    func testSelectInvalidPathThrows() async throws {
        let fs = FakeFileSystem(tree: ["/root": []])
        let engine = makeEngine(fs: fs)
        _ = try await engine.openWorkspace(rootPath: "/root")
        _ = try await engine.refresh()

        await XCTAssertThrowsErrorAsync {
            _ = try await engine.select(path: "/root/missing")
        }
    }

    func testSelectionPersistenceRestoredOnReopen() async throws {
        let fs = FakeFileSystem(tree: [
            "/root": ["src"],
            "/root/src": []
        ])
        let engine = makeEngine(fs: fs)

        _ = try await engine.openWorkspace(rootPath: "/root")
        _ = try await engine.refresh()
        _ = try await engine.select(path: "/root/src")

        // Re-open the workspace; selection should be restored from prefs driver.
        _ = try await engine.openWorkspace(rootPath: "/root")
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.selectedPath, "/root/src")
        XCTAssertEqual(snap.lastPersistedSelection, "/root/src")
    }

    func testSnapshotCarriesSelectedDescriptorID() async throws {
        let fs = FakeFileSystem(tree: [
            "/root": ["src"],
            "/root/src": []
        ])
        let engine = makeEngine(fs: fs)

        _ = try await engine.openWorkspace(rootPath: "/root")
        _ = try await engine.refresh()
        let snap = try await engine.select(path: "/root/src")

        XCTAssertNotNil(snap.selectedDescriptorID)
        XCTAssertEqual(snap.selectedDescriptorID, snap.lastPersistedDescriptorID)
    }

    func testRefreshCancellation() async throws {
        let fs = SlowFileSystem()
        let engine = makeEngine(fs: fs)
        _ = try await engine.openWorkspace(rootPath: "/root")

        let task = Task {
            try await engine.refresh()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        await XCTAssertThrowsErrorAsync {
            try await withTimeout(seconds: 2) {
                _ = try await task.value
            }
        }
    }

    func testSelectionClearsWhenExcluded() async throws {
        let fs = FakeFileSystem(tree: [
            "/root": ["src"],
            "/root/src": []
        ])
        let engine = makeEngine(fs: fs)
        _ = try await engine.openWorkspace(rootPath: "/root")
        _ = try await engine.refresh()
        _ = try await engine.select(path: "/root/src")

        _ = try await engine.setContextInclusion(path: "/root/src", included: false)
        let snap = await engine.snapshot()
        XCTAssertNil(snap.selectedPath)
        XCTAssertNil(snap.lastPersistedSelection)
    }

    func testContextInclusionPersists() async throws {
        let fs = FakeFileSystem(tree: ["/root": ["a.txt"]])
        let engine = makeEngine(fs: fs)
        _ = try await engine.openWorkspace(rootPath: "/root")
        _ = try await engine.refresh()

        let updated = try await engine.setContextInclusion(path: "/root/a.txt", included: true)
        XCTAssertTrue(updated.contextPreferences.includedPaths.contains("/root/a.txt"))

        // Reload preferences to ensure persistence driver saved it.
        let ctx = try await engine.contextPreferences()
        XCTAssertTrue(ctx.contextPreferences.includedPaths.contains("/root/a.txt"))
    }

    func testContextInclusionsExposeDescriptorState() async throws {
        let fs = FakeFileSystem(tree: ["/root": ["a.txt"]])
        let engine = makeEngine(fs: fs)
        _ = try await engine.openWorkspace(rootPath: "/root")
        _ = try await engine.refresh()

        let updated = try await engine.setContextInclusion(path: "/root/a.txt", included: false)
        let descriptorID = updated.descriptorPaths.first(where: { $0.value == "/root/a.txt" })?.key
        XCTAssertNotNil(descriptorID)
        XCTAssertEqual(updated.contextInclusions[descriptorID ?? FileID()], .excluded)
    }

    func testSelectionClearsWhenPathMissingAfterRefresh() async throws {
        let fs = MutableFileSystem(tree: [
            "/root": ["a.txt"]
        ])
        let engine = makeEngine(fs: fs)
        _ = try await engine.openWorkspace(rootPath: "/root")
        _ = try await engine.refresh()
        _ = try await engine.select(path: "/root/a.txt")

        fs.remove(path: "/root/a.txt")
        let snap = try await engine.refresh()
        XCTAssertNil(snap.selectedPath)
        XCTAssertNil(snap.lastPersistedSelection)
    }

    func testExcludedPathsAreNotIndexedAfterRefresh() async throws {
        let fs = MutableFileSystem(tree: [
            "/root": ["a.txt", "b.txt"]
        ])
        let ctxDriver = PreloadedContextPrefs(
            initial: WorkspaceContextPreferencesState(
                includedPaths: [],
                excludedPaths: ["/root/b.txt"],
                lastFocusedFilePath: nil
            )
        )
        let prefsDriver = InMemoryWorkspacePrefs()
        let engine = WorkspaceEngineImpl(
            fileSystem: fs,
            preferences: prefsDriver,
            contextPreferences: ctxDriver,
            watcher: NoopWatcher()
        )

        let snap = try await engine.openWorkspace(rootPath: "/root")
        XCTAssertTrue(snap.descriptorPaths.values.contains("/root/a.txt"))
        XCTAssertFalse(snap.descriptorPaths.values.contains("/root/b.txt"))
    }

    func testConcurrentRefreshAndSelectRemainConsistent() async throws {
        let fs = FakeFileSystem(tree: [
            "/root": ["a.txt"]
        ])
        let engine = makeEngine(fs: fs)
        _ = try await engine.openWorkspace(rootPath: "/root")

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try? await engine.refresh()
            }
            group.addTask {
                _ = try? await engine.select(path: "/root/a.txt")
            }
        }

        let snap = await engine.snapshot()
        XCTAssertTrue(snap.descriptorPaths.values.contains("/root/a.txt"))
    }

    func testConcurrentRefreshAndContextInclusionStayCoherent() async throws {
        let fs = FakeFileSystem(tree: [
            "/root": ["a.txt"]
        ])
        let engine = makeEngine(fs: fs)
        _ = try await engine.openWorkspace(rootPath: "/root")

        async let refreshed: Void? = {
            _ = try? await engine.refresh()
            return nil
        }()

        async let included: Void? = {
            _ = try? await engine.setContextInclusion(path: "/root/a.txt", included: true)
            return nil
        }()

        _ = await (refreshed, included)

        let snap = await engine.snapshot()
        XCTAssertTrue(snap.contextPreferences.includedPaths.contains("/root/a.txt"))
        XCTAssertTrue(snap.descriptorPaths.values.contains("/root/a.txt"))
    }

    func testContextPreferencesPersistenceFailureSurfaces() async throws {
        let fs = FakeFileSystem(tree: ["/root": ["a.txt"]])
        let engine = WorkspaceEngineImpl(
            fileSystem: fs,
            preferences: InMemoryWorkspacePrefs(),
            contextPreferences: FailingContextPrefs(),
            watcher: NoopWatcher()
        )
        _ = try await engine.openWorkspace(rootPath: "/root")
        _ = try await engine.refresh()

        await XCTAssertThrowsErrorAsync {
            _ = try await engine.setContextInclusion(path: "/root/a.txt", included: true)
        }
    }

    func testUpdateStreamSerialWithWatcher() async throws {
        let fs = FakeFileSystem(tree: [
            "/root": ["a.txt"]
        ])
        let watcher = DoubleTickWatcher()
        let engine = WorkspaceEngineImpl(
            fileSystem: fs,
            preferences: InMemoryWorkspacePrefs(),
            contextPreferences: InMemoryContextPrefs(),
            watcher: watcher
        )
        registry.register(engine)

        var iterator = engine.updates().makeAsyncIterator()
        _ = try await engine.openWorkspace(rootPath: "/root")

        let first = await iterator.next()
        let second = await iterator.next()
        let third = await iterator.next()

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertNotNil(third)

        await engine.shutdown()
        let terminated = await iterator.next()
        XCTAssertNil(terminated)
    }

    // MARK: - Helpers

    private func makeEngine(fs: FileSystemAccess) -> WorkspaceEngineImpl<InMemoryWorkspacePrefs, InMemoryContextPrefs> {
        prefs = InMemoryWorkspacePrefs()
        ctxPrefs = InMemoryContextPrefs()
        let engine = WorkspaceEngineImpl(
            fileSystem: fs,
            preferences: prefs,
            contextPreferences: ctxPrefs,
            watcher: NoopWatcher()
        )
        registry.register(engine)
        return engine
    }
}

extension WorkspaceEngineImplTests {
    func testUpdatesStreamCompletesOnShutdown() async throws {
        let engine = makeEngine(fs: FakeFileSystem(tree: ["/root": []]))
        let stream = engine.updates()
        await engine.shutdown()
        var iterator = stream.makeAsyncIterator()
        let next = try await withTimeout(seconds: 2) {
            await iterator.next()
        }
        XCTAssertNil(next, "Updates stream did not finish after shutdown")
    }
}

private struct NoopWatcher: FileSystemWatching {
    func watch(rootPath: String) -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

// MARK: - Fakes

private final class FakeFileSystem: FileSystemAccess, @unchecked Sendable {
    private let tree: [String: [String]]
    private var idForPath: [String: FileID] = [:]
    private var pathForId: [FileID: String] = [:]

    init(tree: [String: [String]]) {
        self.tree = tree
    }

    func resolveRoot(at path: String) throws -> FileID {
        guard tree.keys.contains(path) else { throw EngineError.workspaceNotOpened }
        let id = idForPath[path] ?? FileID()
        idForPath[path] = id
        pathForId[id] = path
        return id
    }

    func listChildren(of id: FileID) throws -> [FileDescriptor] {
        guard let path = pathForId[id] else { return [] }
        let names = tree[path] ?? []
        return names.map { name in
            let childPath = (path as NSString).appendingPathComponent(name)
            let isDirectory = tree.keys.contains(childPath)
            let childId = idForPath[childPath] ?? FileID()
            idForPath[childPath] = childId
            pathForId[childId] = childPath
            return FileDescriptor(
                id: childId,
                name: name,
                type: isDirectory ? .directory : .file,
                children: []
            )
        }
    }

    func metadata(for id: FileID) throws -> FileMetadata {
        guard let path = pathForId[id] else { throw EngineError.workspaceNotOpened }
        let isDirectory = tree.keys.contains(path)
        return FileMetadata(path: path, isDirectory: isDirectory, byteSize: nil)
    }
}

private final class SlowFileSystem: FileSystemAccess, @unchecked Sendable {
    private let rootID = FileID()

    func resolveRoot(at path: String) throws -> FileID {
        guard path == "/root" else { throw EngineError.invalidWorkspace("invalid") }
        return rootID
    }

    func listChildren(of id: FileID) throws -> [FileDescriptor] {
        try Task.checkCancellation()
        Thread.sleep(forTimeInterval: 0.5)
        try Task.checkCancellation()
        return []
    }

    func metadata(for id: FileID) throws -> FileMetadata {
        FileMetadata(path: "/root", isDirectory: true, byteSize: nil)
    }
}

private final class MutableFileSystem: FileSystemAccess, @unchecked Sendable {
    private var tree: [String: [String]]
    private var idForPath: [String: FileID] = [:]
    private var pathForId: [FileID: String] = [:]
    private let lock = NSLock()

    init(tree: [String: [String]]) {
        self.tree = tree
    }

    func resolveRoot(at path: String) throws -> FileID {
        lock.lock()
        defer { lock.unlock() }
        guard tree.keys.contains(path) else { throw EngineError.invalidWorkspace("missing root") }
        let id = idForPath[path] ?? FileID()
        idForPath[path] = id
        pathForId[id] = path
        return id
    }

    func listChildren(of id: FileID) throws -> [FileDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        guard let path = pathForId[id] else { return [] }
        let names = tree[path] ?? []
        return names.compactMap { name in
            let childPath = (path as NSString).appendingPathComponent(name)
            guard tree.keys.contains(path) || tree[path]?.contains(name) == true else { return nil }
            let isDirectory = tree.keys.contains(childPath)
            let childId = idForPath[childPath] ?? FileID()
            idForPath[childPath] = childId
            pathForId[childId] = childPath
            return FileDescriptor(
                id: childId,
                name: name,
                type: isDirectory ? .directory : .file,
                children: []
            )
        }
    }

    func metadata(for id: FileID) throws -> FileMetadata {
        lock.lock()
        defer { lock.unlock() }
        guard let path = pathForId[id] else { throw EngineError.workspaceNotOpened }
        let isDirectory = tree.keys.contains(path)
        return FileMetadata(path: path, isDirectory: isDirectory, byteSize: nil)
    }

    func remove(path: String) {
        lock.lock()
        defer { lock.unlock() }
        let parent = (path as NSString).deletingLastPathComponent
        if var siblings = tree[parent] {
            siblings.removeAll { $0 == (path as NSString).lastPathComponent }
            tree[parent] = siblings
        }
        tree.removeValue(forKey: path)
        if path.hasSuffix("/") {
            tree = tree.filter { !$0.key.hasPrefix(path) }
        }
    }
}

private final class InMemoryWorkspacePrefs: PreferencesDriver, @unchecked Sendable {
    typealias Preferences = WorkspacePreferences
    private var storage: [String: WorkspacePreferences] = [:]

    func loadPreferences(for project: URL) throws -> WorkspacePreferences {
        storage[project.path] ?? .empty
    }

    func savePreferences(_ preferences: WorkspacePreferences, for project: URL) throws {
        storage[project.path] = preferences
    }
}

private final class InMemoryContextPrefs: ContextPreferencesDriver, @unchecked Sendable {
    typealias ContextPreferences = WorkspaceContextPreferencesState
    private var storage: [String: WorkspaceContextPreferencesState] = [:]

    func loadContextPreferences(for project: URL) throws -> WorkspaceContextPreferencesState {
        storage[project.path] ?? .empty
    }

    func saveContextPreferences(_ preferences: WorkspaceContextPreferencesState, for project: URL) throws {
        storage[project.path] = preferences
    }
}

private final class FailingContextPrefs: ContextPreferencesDriver, @unchecked Sendable {
    typealias ContextPreferences = WorkspaceContextPreferencesState
    func loadContextPreferences(for project: URL) throws -> WorkspaceContextPreferencesState { .empty }
    func saveContextPreferences(_ preferences: WorkspaceContextPreferencesState, for project: URL) throws {
        throw EngineError.persistenceFailed(underlying: "simulated failure")
    }
}

private final class PreloadedContextPrefs: ContextPreferencesDriver, @unchecked Sendable {
    typealias ContextPreferences = WorkspaceContextPreferencesState
    private var storage: WorkspaceContextPreferencesState

    init(initial: WorkspaceContextPreferencesState) {
        self.storage = initial
    }

    func loadContextPreferences(for project: URL) throws -> WorkspaceContextPreferencesState {
        storage
    }

    func saveContextPreferences(_ preferences: WorkspaceContextPreferencesState, for project: URL) throws {
        storage = preferences
    }
}

private final class DoubleTickWatcher: FileSystemWatching {
    func watch(rootPath: String) -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.yield(())
            Task.detached {
                try? await Task.sleep(nanoseconds: 50_000_000)
                continuation.yield(())
                continuation.finish()
            }
        }
    }
}

private func XCTAssertThrowsErrorAsync(_ block: @escaping () async throws -> Void) async {
    do {
        try await block()
        XCTFail("Expected error, got success")
    } catch {
        // success
    }
}

private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw CancellationError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

