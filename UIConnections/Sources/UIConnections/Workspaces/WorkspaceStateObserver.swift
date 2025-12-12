import Foundation
import Combine
import AppCoreEngine

/// Observes workspace engine updates and projects to presentation model and projection.
/// Power: Descriptive (observes and projects, does not decide)
/// Coordinator decides when projections are updated.
@MainActor
public final class WorkspaceStateObserver {
    private let workspaceEngine: WorkspaceEngine
    private let presentationModel: WorkspacePresentationModel
    private let projection: WorkspaceProjection
    private var updatesTask: Task<Void, Never>?
    
    public init(
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
    
    private func applyUpdate(_ update: WorkspaceUpdate) {
        // Project to projection model (domain-derived state)
        let previousRoot = projection.workspaceState.rootPath
        let notice: WorkspaceErrorNotice? = {
            guard let err = update.error else { return nil }
            switch err {
            case .watcherUnavailable: return .watcherUnavailable
            case .refreshFailed(let message): return .refreshFailed(message)
            }
        }()
        let mapped = WorkspaceViewStateMapper.map(update: update, watcherError: notice)
        projection.workspaceState = mapped
        
        if previousRoot != mapped.rootPath {
            presentationModel.expandedDescriptorIDs.removeAll()
            presentationModel.selectedNode = nil
            presentationModel.selectedDescriptorID = nil
        }
        
        presentationModel.selectedDescriptorID = mapped.selectedDescriptorID
        if let selectedDescriptorID = mapped.selectedDescriptorID,
           let projection = mapped.projection,
           let node = FileNode.fromProjection(projection).findNode(withDescriptorID: selectedDescriptorID) {
            presentationModel.selectedNode = node
        } else {
            updateSelectedNode()
        }
        
        if let projection = mapped.projection {
            presentationModel.rootFileNode = FileNode.fromProjection(projection)
        }
        
        presentationModel.watcherError = mapped.watcherError
    }
    
    private func updateSelectedNode() {
        guard let descriptorID = presentationModel.selectedDescriptorID else {
            presentationModel.selectedNode = nil
            return
        }
        presentationModel.selectedNode = presentationModel.rootFileNode?.findNode(withDescriptorID: descriptorID)
    }
    
    func cancel() {
        updatesTask?.cancel()
        updatesTask = nil
    }
}

