import XCTest
@testable import CoreEngine

final class WorkspaceEngineUpdatesTests: XCTestCase {
    private var prefs: InMemoryWorkspacePrefs!
    private var ctxPrefs: InMemoryContextPrefs!

    func testUpdatesEmitOnRefreshAndCoalesce() async throws {
        let fs = MutableFileSystem(tree: [
            "/root": ["a.txt"]
        ])
        let engine = makeEngine(fs: fs)

        _ = try await engine.openWorkspace(rootPath: "/root")

        var snapshots: [WorkspaceSnapshot] = []
        var projections: [WorkspaceTreeProjection?] = []
        let expectation = expectation(description: "Receive updates")
        expectation.expectedFulfillmentCount = 2

        let streamTask = Task {
            for await update in engine.updates() {
                snapshots.append(update.snapshot)
                projections.append(update.projection)
                expectation.fulfill()
                if snapshots.count == 2 { break }
            }
        }

        // First update comes from openWorkspace watcher kick-off, second after change.
        fs.add(path: "/root/b.txt")
        try await Task.sleep(nanoseconds: 400_000_000) // > debounce

        await fulfillment(of: [expectation], timeout: 2.0)
        streamTask.cancel()

        XCTAssertGreaterThanOrEqual(snapshots.count, 2)
        XCTAssertGreaterThanOrEqual(projections.count, 2)
        XCTAssertNotNil(projections.last ?? nil)
    }

    func testUpdatesPreserveInclusionsAndSelection() async throws {
        let fs = MutableFileSystem(tree: [
            "/root": ["a.txt", "b.txt"]
        ])
        let engine = makeEngine(fs: fs)
        _ = try await engine.openWorkspace(rootPath: "/root")

        var iterator = engine.updates().makeAsyncIterator()
        _ = await iterator.next() // consume initial update if present

        _ = try await engine.setContextInclusion(path: "/root/b.txt", included: false)

        var found = false
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            if let update = await iterator.next(),
               update.snapshot.contextPreferences.excludedPaths.contains("/root/b.txt") {
                found = true
                break
            }
        }
        XCTAssertTrue(found)
    }

    // MARK: - Helpers

    private func makeEngine(fs: FileSystemAccess) -> WorkspaceEngineImpl<InMemoryWorkspacePrefs, InMemoryContextPrefs> {
        prefs = InMemoryWorkspacePrefs()
        ctxPrefs = InMemoryContextPrefs()
        return WorkspaceEngineImpl(
            fileSystem: fs,
            preferences: prefs,
            contextPreferences: ctxPrefs,
            watcher: NoopWatcher()
        )
    }
}

private struct NoopWatcher: FileSystemWatching {
    func watch(rootPath: String) -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

// MARK: - Mutable fake FS for watcher tests

private final class MutableFileSystem: FileSystemAccess, @unchecked Sendable {
    private var tree: [String: [String]]
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

    func add(path: String) {
        let parent = (path as NSString).deletingLastPathComponent
        let name = (path as NSString).lastPathComponent
        var entries = tree[parent] ?? []
        if !entries.contains(name) {
            entries.append(name)
            tree[parent] = entries
        }
        if tree.keys.contains(path) == false && path.hasSuffix("/") {
            tree[path] = []
        }
    }

    func metadata(for id: FileID) throws -> FileMetadata {
        guard let path = pathForId[id] else {
            return FileMetadata(path: "", isDirectory: false, byteSize: nil)
        }
        let isDir = tree.keys.contains(path)
        return FileMetadata(path: path, isDirectory: isDir, byteSize: nil)
    }
}

// Minimal in-memory prefs for tests
private final class InMemoryWorkspacePrefs: PreferencesDriver, @unchecked Sendable {
    typealias Preferences = WorkspacePreferences
    private var storage: [URL: Preferences] = [:]
    func loadPreferences(for root: URL) throws -> WorkspacePreferences {
        storage[root] ?? .empty
    }
    func savePreferences(_ preferences: WorkspacePreferences, for root: URL) throws {
        storage[root] = preferences
    }
}

private final class InMemoryContextPrefs: ContextPreferencesDriver, @unchecked Sendable {
    typealias ContextPreferences = WorkspaceContextPreferencesState
    private var storage: [URL: ContextPreferences] = [:]
    func loadContextPreferences(for root: URL) throws -> WorkspaceContextPreferencesState {
        storage[root] ?? .empty
    }
    func saveContextPreferences(_ preferences: WorkspaceContextPreferencesState, for root: URL) throws {
        storage[root] = preferences
    }
}

