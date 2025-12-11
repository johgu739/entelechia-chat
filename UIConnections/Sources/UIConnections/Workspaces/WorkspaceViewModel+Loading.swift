import Foundation
import AppCoreEngine

extension WorkspaceViewModel {
    func openWorkspace(at url: URL) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await withTimeout(seconds: 30) { [self] in
                try await workspaceEngine.openWorkspace(rootPath: url.path)
            }
            applyUpdate(
                WorkspaceUpdate(
                    snapshot: snapshot,
                    projection: await workspaceEngine.treeProjection(),
                    error: nil
                )
            )
            loadProjectTodos(for: url)
        } catch let timeout as TimeoutError {
            handleFileSystemError(timeout, fallbackTitle: "Load Timed Out")
            applyUpdate(WorkspaceUpdate(snapshot: .empty, projection: nil, error: nil))
            rootFileNode = nil
        } catch {
            handleFileSystemError(error, fallbackTitle: "Failed to Load Project")
            applyUpdate(WorkspaceUpdate(snapshot: .empty, projection: nil, error: nil))
            rootFileNode = nil
        }
    }
    
    func selectPath(_ url: URL?) async {
        do {
            let snapshot = try await withTimeout(seconds: 10) { [self] in
                try await workspaceEngine.select(path: url?.path)
            }
            applyUpdate(
                WorkspaceUpdate(
                    snapshot: snapshot,
                    projection: await workspaceEngine.treeProjection(),
                    error: nil
                )
            )
        } catch let timeout as TimeoutError {
            handleFileSystemError(timeout, fallbackTitle: "Selection Timed Out")
        } catch {
            handleFileSystemError(error, fallbackTitle: "Failed to Select File")
        }
    }
    
    func applyUpdate(_ update: WorkspaceUpdate) {
        workspaceSnapshot = update.snapshot
        let previousRoot = workspaceState.rootPath
        let notice: WorkspaceErrorNotice? = {
            guard let err = update.error else { return nil }
            switch err {
            case .watcherUnavailable: return .watcherUnavailable
            case .refreshFailed(let message): return .refreshFailed(message)
            }
        }()
        let mapped = WorkspaceViewStateMapper.map(update: update, watcherError: notice)
        workspaceState = mapped
        if previousRoot != mapped.rootPath {
            expandedDescriptorIDs.removeAll()
            selectedNode = nil
            selectedDescriptorID = nil
        }
        selectedDescriptorID = mapped.selectedDescriptorID
        if let selectedDescriptorID,
           let projection = mapped.projection,
           let node = FileNode.fromProjection(projection).findNode(withDescriptorID: selectedDescriptorID) {
            selectedNode = node
        } else {
            updateSelectedNode()
        }
        if let projection = mapped.projection {
            rootFileNode = FileNode.fromProjection(projection)
        }
        watcherError = mapped.watcherError
    }
    
    func applySnapshot(_ snapshot: WorkspaceSnapshot, projection: WorkspaceTreeProjection?) {
        let update = WorkspaceUpdate(snapshot: snapshot, projection: projection, error: nil)
        applyUpdate(update)
    }
    
    func subscribeToUpdates() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await update in self.workspaceEngine.updates() {
                await MainActor.run {
                    self.applyUpdate(update)
                }
            }
        }
    }
    
    func updateSelectedNode() {
        guard let descriptorID = selectedDescriptorID else {
            selectedNode = nil
            return
        }
        selectedNode = rootFileNode?.findNode(withDescriptorID: descriptorID)
    }
}

