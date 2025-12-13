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
    private var onStateUpdated: (() -> Void)?
    private var lastStructuralState: (rootPath: String?, descriptorCount: Int, descriptorPathCount: Int)?
    
    init(
        workspaceEngine: WorkspaceEngine,
        presentationModel: WorkspacePresentationModel,
        projection: WorkspaceProjection,
        onStateUpdated: (() -> Void)? = nil
    ) {
        self.workspaceEngine = workspaceEngine
        self.presentationModel = presentationModel
        self.projection = projection
        self.onStateUpdated = onStateUpdated
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
        let previousSelection = projection.workspaceState.selectedDescriptorID
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
        
        // Classify update before mutating state
        let updateType = classifyUpdate(
            snapshot: snapshot,
            previousRoot: previousRoot,
            newRoot: mapped.rootPath,
            previousSelection: previousSelection,
            newSelection: snapshot.selectedDescriptorID
        )
        let isStructural = updateType == .structural
        
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
        
        // Rebuild tree only for structural changes (single call)
        if isStructural, let domainProjection = update.projection {
            presentationModel.rootFileNode = FileNode.fromProjection(domainProjection)
        }
        
        // Update selection against existing tree (structural or not)
        updateSelectedNode()
        
        presentationModel.watcherError = mapped.watcherError
        
        // Trigger reactive UI update after state mutation
        onStateUpdated?()
    }
    
    private enum UpdateType {
        case structural
        case selectionOnly
        case contextOnly
    }
    
    private func classifyUpdate(
        snapshot: WorkspaceSnapshot,
        previousRoot: String?,
        newRoot: String?,
        previousSelection: UUID?,
        newSelection: AppCoreEngine.FileID?
    ) -> UpdateType {
        let currentStructural = (
            rootPath: snapshot.rootPath,
            descriptorCount: snapshot.descriptors.count,
            descriptorPathCount: snapshot.descriptorPaths.count
        )
        
        // First update or root change is always structural
        guard let last = lastStructuralState else {
            lastStructuralState = currentStructural
            return .structural
        }
        
        // Check for structural changes
        let rootChanged = last.rootPath != currentStructural.rootPath
        let descriptorCountChanged = last.descriptorCount != currentStructural.descriptorCount
        let descriptorPathCountChanged = last.descriptorPathCount != currentStructural.descriptorPathCount
        
        if rootChanged || descriptorCountChanged || descriptorPathCountChanged {
            lastStructuralState = currentStructural
            return .structural
        }
        
        // If structure unchanged, check if selection changed
        let selectionChanged = previousSelection != newSelection?.rawValue
        
        if selectionChanged {
            return .selectionOnly
        } else {
            return .contextOnly
        }
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

