// @EntelechiaHeaderStart
// Signifier: WorkspaceViewModel
// Substance: Workspace UI faculty
// Genus: Application faculty
// Differentia: Mediates workspace domain to UI
// Form: State for selection, root, expansion, conversations
// Matter: URLs; FileNode tree; selection sets
// Powers: Load tree; manage selection; map conversations
// FinalCause: Mediate between domain services and UI
// Relations: Depends on workspace services/stores; serves UI
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import Combine
import os.log
import AppCoreEngine

public enum WorkspaceViewModelError: LocalizedError {
    case invalidProjectPath(String)
    case unreadableProject(String)
    case emptyProject(String)
    case selectionPersistenceFailed(Error)
    case conversationEnsureFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidProjectPath(let path):
            return "Project path is invalid: \(path)"
        case .unreadableProject(let path):
            return "Project directory could not be read: \(path)"
        case .emptyProject(let path):
            return "Project directory is empty: \(path)"
        case .selectionPersistenceFailed:
            return "Failed to remember the last selected file."
        case .conversationEnsureFailed:
            return "Failed to prepare the conversation for the selected file."
        }
    }

    public var failureReason: String? {
        switch self {
        case .selectionPersistenceFailed(let error),
            .conversationEnsureFailed(let error):
            return error.localizedDescription
        default:
            return errorDescription
        }
    }
}

// MARK: - Null Codex for tests/DI defaults
public struct NullCodexQuerying: CodexQuerying {
    public init() {}
    public func askAboutWorkspaceNode(
        scope: WorkspaceScope,
        question: String,
        onStream: ((String) -> Void)?
    ) async throws -> CodexAnswer {
        throw WorkspaceViewModelError.conversationEnsureFailed(
            EngineError.contextLoadFailed("Codex unavailable")
        )
    }
}

/// Navigator mode matching Xcode's navigator tabs
public enum NavigatorMode: String, CaseIterable {
    case project = "Project"
    case todos = "Ontology TODOs"
    case search = "Search"
    case issues = "Issues"
    case tests = "Tests"
    case reports = "Reports"
    
    public var icon: String {
        switch self {
        case .project: return "folder"
        case .todos: return "checklist"
        case .search: return "magnifyingglass"
        case .issues: return "exclamationmark.triangle"
        case .tests: return "checkmark.circle"
        case .reports: return "chart.bar"
        }
    }
}

@MainActor
public final class WorkspaceViewModel: ObservableObject, ConversationWorkspaceHandling {
    // MARK: - Published State (UI State Only)
    
    @Published public var selectedNode: FileNode?
    @Published public var rootFileNode: FileNode?
    @Published public var isLoading: Bool = false
    @Published public var filterText: String = ""
    @Published public var activeNavigator: NavigatorMode = .project
    @Published public var expandedDescriptorIDs: Set<FileID> = []
    @Published public var projectTodos: ProjectTodos = .empty
    @Published public var todosError: String?
    @Published var streamingMessages: [UUID: String] = [:]
    @Published public var lastContextResult: ContextBuildResult?
    @Published public var lastContextSnapshot: ContextSnapshot?
    @Published public var activeScope: ContextScopeChoice = .selection
    @Published public var modelChoice: ModelChoice = .codex
    @Published public var selectedDescriptorID: FileID?
    @Published var workspaceState: WorkspaceViewState = WorkspaceViewState(
        rootPath: nil,
        selectedDescriptorID: nil,
        selectedPath: nil,
        projection: nil,
        contextInclusions: [:],
        watcherError: nil
    )
    @Published public var watcherError: String?
    var updatesTask: Task<Void, Never>?
    
    // MARK: - Dependencies (Services)
    
    let workspaceEngine: WorkspaceEngine
    let conversationEngine: ConversationStreaming
    let projectTodosLoader: ProjectTodosLoading
    let codexService: CodexQuerying
    var alertCenter: AlertCenter?
    let contextSelection: ContextSelectionState
    let logger = Logger(subsystem: "UIConnections", category: "WorkspaceViewModel")
    let contextErrorSubject = PassthroughSubject<Error, Never>()
    var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Derived State
    
    public var rootDirectory: URL? {
        workspaceSnapshot.rootPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }
    
    var descriptorPaths: [FileID: String] {
        workspaceState.projection?.flattenedPaths ?? [:]
    }
    
    // MARK: - Private State
    var workspaceSnapshot: WorkspaceSnapshot = .empty
    var codexContextByMessageID: [UUID: ContextBuildResult] = [:]
    
    // MARK: - Initialization
    
    public init(
        workspaceEngine: WorkspaceEngine,
        conversationEngine: ConversationStreaming,
        projectTodosLoader: ProjectTodosLoading,
        codexService: CodexQuerying = NullCodexQuerying(),
        alertCenter: AlertCenter? = nil,
        contextSelection: ContextSelectionState = ContextSelectionState()
    ) {
        self.workspaceEngine = workspaceEngine
        self.conversationEngine = conversationEngine
        self.projectTodosLoader = projectTodosLoader
        self.codexService = codexService
        self.alertCenter = alertCenter
        self.contextSelection = contextSelection
        bindContextSelection()
        subscribeToUpdates()
    }

    public func setAlertCenter(_ center: AlertCenter) {
        guard alertCenter == nil else { return }
        alertCenter = center
    }
}
