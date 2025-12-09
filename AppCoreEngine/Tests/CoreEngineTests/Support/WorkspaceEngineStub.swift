import Foundation
import AppCoreEngine

/// Test-only workspace engine stub; uses a serial queue for thread safety.
final class WorkspaceEngineStub: WorkspaceEngine, @unchecked Sendable {
    private var currentSnapshot = WorkspaceSnapshot.empty
    private let queue = DispatchQueue(label: "WorkspaceEngineStub.queue")

    init() {}

    func openWorkspace(rootPath: String) async throws -> WorkspaceSnapshot {
        return queue.sync {
            currentSnapshot = makeSnapshot(
                rootPath: rootPath,
                selectedPath: nil,
                lastPersistedSelection: nil,
                contextPreferences: currentSnapshot.contextPreferences
            )
            return currentSnapshot
        }
    }

    func treeProjection() async -> WorkspaceTreeProjection? { nil }

    func snapshot() async -> WorkspaceSnapshot {
        queue.sync { currentSnapshot }
    }

    func refresh() async throws -> WorkspaceSnapshot {
        queue.sync { currentSnapshot }
    }

    func select(path: String?) async throws -> WorkspaceSnapshot {
        return queue.sync {
            currentSnapshot = makeSnapshot(
                rootPath: currentSnapshot.rootPath,
                selectedPath: path,
                lastPersistedSelection: path,
                contextPreferences: currentSnapshot.contextPreferences
            )
            return currentSnapshot
        }
    }

    func contextPreferences() async throws -> WorkspaceSnapshot {
        queue.sync { currentSnapshot }
    }

    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot {
        return queue.sync {
            var prefs = currentSnapshot.contextPreferences
            if included {
                prefs.includedPaths.insert(path)
                prefs.excludedPaths.remove(path)
            } else {
                prefs.includedPaths.remove(path)
                prefs.excludedPaths.insert(path)
            }
            currentSnapshot = makeSnapshot(
                rootPath: currentSnapshot.rootPath,
                selectedPath: currentSnapshot.selectedPath,
                lastPersistedSelection: currentSnapshot.lastPersistedSelection,
                contextPreferences: prefs
            )
            return currentSnapshot
        }
    }

    func updates() -> AsyncStream<WorkspaceUpdate> {
        let snap = queue.sync { currentSnapshot }
        return AsyncStream { continuation in
            continuation.yield(WorkspaceUpdate(snapshot: snap, projection: nil))
            continuation.finish()
        }
    }

    private func makeSnapshot(
        rootPath: String?,
        selectedPath: String?,
        lastPersistedSelection: String?,
        contextPreferences: WorkspaceContextPreferencesState
    ) -> WorkspaceSnapshot {
        let contextInclusions: [FileID: ContextInclusionState] = [:]
        return WorkspaceSnapshot(
            rootPath: rootPath,
            selectedPath: selectedPath,
            lastPersistedSelection: lastPersistedSelection,
            selectedDescriptorID: nil,
            lastPersistedDescriptorID: nil,
            contextPreferences: contextPreferences,
            descriptorPaths: [:],
            contextInclusions: contextInclusions,
            descriptors: currentSnapshot.descriptors
        )
    }
}

