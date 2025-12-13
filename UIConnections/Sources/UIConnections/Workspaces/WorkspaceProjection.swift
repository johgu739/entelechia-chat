import Foundation
import Combine
import AppCoreEngine
import UIContracts

/// Read-only projections derived from domain streams.
/// Power: Descriptive (projects domain state to UI-readable form)
/// Contains domain-derived artifacts, not user-controlled UI state.
@MainActor
public final class WorkspaceProjection: ObservableObject {
    // MARK: - Domain Projections (Derived from Domain Streams)
    
    @Published public var workspaceState: UIContracts.WorkspaceViewState = UIContracts.WorkspaceViewState(
        rootPath: nil,
        selectedDescriptorID: nil,
        selectedPath: nil,
        projection: nil,
        contextInclusions: [:],
        watcherError: nil
    )
    
    public init() {}
}

