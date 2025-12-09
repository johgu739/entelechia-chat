import XCTest
@testable import UIConnections
import AppCoreEngine

final class WorkspaceMapperCompletenessTests: XCTestCase {

    func testWorkspaceSnapshotMapsAllFields() {
        let id = FileID()
        let snapshot = WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: "/root/file.swift",
            lastPersistedSelection: "/root/file.swift",
            selectedDescriptorID: id,
            lastPersistedDescriptorID: id,
            contextPreferences: WorkspaceContextPreferencesState(
                includedPaths: ["/root/file.swift"],
                excludedPaths: ["/root/other.swift"],
                lastFocusedFilePath: "/root/file.swift"
            ),
            descriptorPaths: [id: "/root/file.swift"],
            contextInclusions: [id: .included],
            descriptors: [
                FileDescriptor(id: id, name: "file.swift", type: .file)
            ]
        )

        let projection = WorkspaceTreeProjection(
            id: id,
            name: "file.swift",
            path: "/root/file.swift",
            isDirectory: false,
            children: []
        )

        let update = WorkspaceUpdate(snapshot: snapshot, projection: projection, error: .watcherUnavailable)
        let viewState = WorkspaceViewStateMapper.map(update: update, watcherError: .watcherUnavailable)

        XCTAssertEqual(viewState.rootPath, snapshot.rootPath)
        XCTAssertEqual(viewState.selectedPath, snapshot.selectedPath)
        XCTAssertEqual(viewState.selectedDescriptorID, snapshot.selectedDescriptorID)
        XCTAssertEqual(viewState.contextInclusions, snapshot.contextInclusions)
        XCTAssertEqual(viewState.projection?.path, projection.path)
        XCTAssertEqual(viewState.projection?.name, projection.name)
        XCTAssertEqual(viewState.projection?.isDirectory, projection.isDirectory)
        XCTAssertEqual(viewState.watcherError, "Workspace watcher stopped (root missing or inaccessible).")
    }
}

