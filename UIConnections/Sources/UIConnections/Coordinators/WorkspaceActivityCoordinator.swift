import Foundation
import Combine
import AppCoreEngine

/// Coordinator for workspace activity operations (moved from AppComposition).
/// Handles workspace opening when project URL changes.
@MainActor
public final class WorkspaceActivityCoordinator: ObservableObject {
    private let workspaceActivityViewModel: WorkspaceActivityViewModel
    private var cancellables: Set<AnyCancellable> = []
    
    public init(workspaceActivityViewModel: WorkspaceActivityViewModel) {
        self.workspaceActivityViewModel = workspaceActivityViewModel
    }
    
    /// Observe project session and open workspace when project URL changes.
    public func observeProjectSession(_ projectSession: ProjectSession) {
        projectSession.$activeProjectURL
            .sink { [weak self] newURL in
                if let url = newURL {
                    Task {
                        await self?.workspaceActivityViewModel.openWorkspace(at: url)
                    }
                }
            }
            .store(in: &cancellables)
    }
}

