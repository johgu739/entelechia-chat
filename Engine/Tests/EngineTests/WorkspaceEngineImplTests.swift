import XCTest
@testable import Engine

final class WorkspaceEngineImplTests: XCTestCase {
    private var prefs: InMemoryWorkspacePrefs!
    private var ctxPrefs: InMemoryContextPrefs!

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
        XCTAssertEqual(engine.state().selectedPath, "/root/src")
        XCTAssertEqual(engine.state().lastPersistedSelection, "/root/src")
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
        XCTAssertNil(engine.state().selectedPath)
        XCTAssertNil(engine.state().lastPersistedSelection)
    }

    func testContextInclusionPersists() async throws {
        let fs = FakeFileSystem(tree: ["/root": ["a.txt"]])
        let engine = makeEngine(fs: fs)
        _ = try await engine.openWorkspace(rootPath: "/root")
        _ = try await engine.refresh()

        let updated = try await engine.setContextInclusion(path: "/root/a.txt", included: true)
        XCTAssertTrue(updated.includedPaths.contains("/root/a.txt"))

        // Reload preferences to ensure persistence driver saved it.
        let ctx = try await engine.contextPreferences()
        XCTAssertTrue(ctx.includedPaths.contains("/root/a.txt"))
    }

    // MARK: - Helpers

    private func makeEngine(fs: FakeFileSystem) -> WorkspaceEngineImpl<InMemoryWorkspacePrefs, InMemoryContextPrefs> {
        prefs = InMemoryWorkspacePrefs()
        ctxPrefs = InMemoryContextPrefs()
        return WorkspaceEngineImpl(
            fileSystem: fs,
            preferences: prefs,
            contextPreferences: ctxPrefs
        )
    }
}

// MARK: - Fakes

private final class FakeFileSystem: FileSystemAccess {
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

private final class InMemoryWorkspacePrefs: PreferencesDriver {
    typealias Preferences = WorkspacePreferences
    private var storage: [String: WorkspacePreferences] = [:]

    func loadPreferences(for project: URL) throws -> WorkspacePreferences {
        storage[project.path] ?? .empty
    }

    func savePreferences(_ preferences: WorkspacePreferences, for project: URL) throws {
        storage[project.path] = preferences
    }
}

private final class InMemoryContextPrefs: ContextPreferencesDriver {
    typealias ContextPreferences = WorkspaceContextPreferencesState
    private var storage: [String: WorkspaceContextPreferencesState] = [:]

    func loadContextPreferences(for project: URL) throws -> WorkspaceContextPreferencesState {
        storage[project.path] ?? .empty
    }

    func saveContextPreferences(_ preferences: WorkspaceContextPreferencesState, for project: URL) throws {
        storage[project.path] = preferences
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

