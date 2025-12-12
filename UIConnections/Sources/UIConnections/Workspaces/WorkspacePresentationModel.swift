import Foundation
import Combine
import AppCoreEngine

/// Internal UI state container for workspace presentation.
/// UIConnections uses this internally; external code should not use it.
/// Power: Descriptive (UI state only, no domain echoes)
/// Contains only user-controlled UI state, not domain-derived projections.
@MainActor
internal final class WorkspacePresentationModel: ObservableObject {
    // MARK: - Published UI State (Pure UI, No Domain Artifacts)
    
    @Published public var selectedNode: FileNode?
    @Published public var rootFileNode: FileNode?
    @Published public var isLoading: Bool = false
    @Published public var filterText: String = ""
    @Published public var activeNavigator: NavigatorMode = .project
    @Published public var expandedDescriptorIDs: Set<FileID> = []
    @Published public var projectTodos: ProjectTodos = .empty
    @Published public var todosError: String?
    @Published public var activeScope: ContextScopeChoice = .selection
    @Published public var modelChoice: ModelChoice = .codex
    @Published public var selectedDescriptorID: FileID?
    @Published public var watcherError: String?
    
    public init() {}
}

