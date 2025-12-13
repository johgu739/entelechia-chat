import Foundation
import Combine
import AppCoreEngine
import UIContracts

/// Internal UI state container for workspace presentation.
/// UIConnections uses this internally; external code should not use it.
/// Power: Descriptive (UI state only, no domain echoes)
/// Contains only user-controlled UI state, not domain-derived projections.
@MainActor
internal final class WorkspacePresentationModel: ObservableObject {
    // MARK: - Published UI State (Pure UI, No Domain Artifacts)
    
    @Published public var rootFileNode: FileNode?
    @Published public var isLoading: Bool = false
    @Published public var filterText: String = ""
    @Published public var activeNavigator: NavigatorMode = .project
    @Published public var expandedDescriptorIDs: Set<UIContracts.FileID> = []
    @Published public var projectTodos: UIContracts.ProjectTodos = .empty
    @Published public var todosError: String?
    @Published public var activeScope: UIContracts.ContextScopeChoice = .selection
    @Published public var modelChoice: UIContracts.ModelChoice = .codex
    @Published public var watcherError: String?
    
    public init() {}
}

