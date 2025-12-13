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
    private var onDetailReplaced: ((UIContracts.FileID?) -> Void)?
    private var lastStructuralState: (rootPath: String?, descriptorCount: Int, descriptorPathCount: Int)?
    
    init(
        workspaceEngine: WorkspaceEngine,
        presentationModel: WorkspacePresentationModel,
        projection: WorkspaceProjection,
        onStateUpdated: (() -> Void)? = nil,
        onDetailReplaced: ((UIContracts.FileID?) -> Void)? = nil
    ) {
        self.workspaceEngine = workspaceEngine
        self.presentationModel = presentationModel
        self.projection = projection
        self.onStateUpdated = onStateUpdated
        self.onDetailReplaced = onDetailReplaced
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
        // INVARIANT 3: MainActor protection - tree rebuilds must be on MainActor
        precondition(Thread.isMainThread, "applyUpdate must run on MainActor")
        
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
        
        // INVARIANT 1: Selection-only updates must not rebuild tree
        if updateType == .selectionOnly {
            precondition(!isStructural, "Selection-only update must not be classified as structural")
        }
        
        projection.workspaceState = mapped
        
        if previousRoot != mapped.rootPath {
            presentationModel.expandedDescriptorIDs.removeAll()
        }
        
        // INVARIANT 1: Single structural rebuild - FileNode.fromProjection called at most once per update
        // Only for structural changes, and only if projection exists
        var treeRebuilt = false
        if isStructural, let domainProjection = update.projection {
            presentationModel.rootFileNode = FileNode.fromProjection(domainProjection)
            treeRebuilt = true
        }
        
        // INVARIANT 1: Guard - non-structural updates must not rebuild tree
        if !isStructural {
            precondition(!treeRebuilt, "Non-structural update must not rebuild tree")
        }
        
        // Replace detail state on selection change
        let newSelection = mapped.selectedDescriptorID.map { UIContracts.FileID($0) }
        let selectionChanged = previousSelection != mapped.selectedDescriptorID
        if selectionChanged {
            onDetailReplaced?(newSelection)
        }
        
        presentationModel.watcherError = mapped.watcherError
        
        // INVARIANT 2: Reactive view-state derivation - trigger only after state mutation completes
        // This ensures updateViewStates() reads consistent state
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
    
    
    func cancel() {
        updatesTask?.cancel()
        updatesTask = nil
    }
}

