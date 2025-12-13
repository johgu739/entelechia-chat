import Foundation
import Combine
import AppCoreEngine
import UIContracts

/// Observes workspace engine updates and projects to presentation model and projection.
/// Power: Descriptive (observes and projects, does not decide)
/// Coordinator decides when projections are updated.
@MainActor
public final class WorkspaceStateObserver {
    private let workspaceEngine: WorkspaceEngine
    private let presentationModel: WorkspacePresentationModel
    private let projection: WorkspaceProjection
    private var updatesTask: Task<Void, Never>?
    
    init(
        workspaceEngine: WorkspaceEngine,
        presentationModel: WorkspacePresentationModel,
        projection: WorkspaceProjection
    ) {
        self.workspaceEngine = workspaceEngine
        self.presentationModel = presentationModel
        self.projection = projection
        subscribeToUpdates()
    }
    
    private func subscribeToUpdates() {
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
    
    private func applyUpdate(_ update: AppCoreEngine.WorkspaceUpdate) {
        // Project to projection model (domain-derived state)
        let previousRoot = projection.workspaceState.rootPath
        let watcherError: String? = {
            guard let err = update.error else { return nil }
            switch err {
            case .watcherUnavailable: return "Watcher unavailable"
            case .refreshFailed(let message): return message
            }
        }()
        let snapshot = update.snapshot
        let mapped = DomainToUIMappers.toWorkspaceViewState(
            rootPath: snapshot.rootPath,
            selectedDescriptorID: snapshot.selectedDescriptorID,
            selectedPath: snapshot.selectedPath,
            projection: update.projection,
            contextInclusions: snapshot.contextInclusions,
            watcherError: watcherError
        )
        projection.workspaceState = mapped
        
        if previousRoot != mapped.rootPath {
            presentationModel.expandedDescriptorIDs.removeAll()
            presentationModel.selectedNode = nil
            presentationModel.selectedDescriptorID = nil
        }
        
        if let uuid = mapped.selectedDescriptorID {
            presentationModel.selectedDescriptorID = UIContracts.FileID(uuid)
        } else {
            presentationModel.selectedDescriptorID = nil
        }
        
        // Use domain projection directly from update for FileNode creation
        // This is temporary - FileNode should be eliminated (violation A6)
        if let domainProjection = update.projection {
            if let uuid = mapped.selectedDescriptorID {
                let engineFileID = AppCoreEngine.FileID(uuid)
                if let node = FileNode.fromProjection(domainProjection).findNode(withDescriptorID: engineFileID) {
                    presentationModel.selectedNode = node
                } else {
                    updateSelectedNode()
                }
            } else {
                updateSelectedNode()
            }
            presentationModel.rootFileNode = FileNode.fromProjection(domainProjection)
        }
        
        presentationModel.watcherError = mapped.watcherError
    }
    
    private func updateSelectedNode() {
        guard let descriptorID = presentationModel.selectedDescriptorID else {
            presentationModel.selectedNode = nil
            return
        }
        let engineFileID = AppCoreEngine.FileID(descriptorID.rawValue)
        presentationModel.selectedNode = presentationModel.rootFileNode?.findNode(withDescriptorID: engineFileID)
    }
    
    func cancel() {
        updatesTask?.cancel()
        updatesTask = nil
    }
}

