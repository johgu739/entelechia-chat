import Foundation
import Combine
import AppCoreEngine

/// Coordinator for workspace activity operations (moved from AppComposition).
/// Handles workspace opening when project URL changes.
@MainActor
public final class WorkspaceActivityCoordinator: ObservableObject {
    private let onOpenWorkspace: (URL) async -> Void
    private var cancellables: Set<AnyCancellable> = []
    
    public init(onOpenWorkspace: @escaping (URL) async -> Void) {
        self.onOpenWorkspace = onOpenWorkspace
    }
    
    /// Observe project session and open workspace when project URL changes.
    public func observeProjectSession(_ projectSession: ProjectSession) {
        projectSession.$activeProjectURL
            .sink { [weak self] newURL in
                if let url = newURL {
                    Task {
                        await self?.onOpenWorkspace(url)
                    }
                }
            }
            .store(in: &cancellables)
    }
}

