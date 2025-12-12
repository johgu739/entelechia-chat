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

/// Thin wrapper for backward compatibility.
/// Delegates to WorkspaceCoordinator, WorkspacePresentationModel, and WorkspaceProjection.
/// Power: Descriptive (thin mapping/facade only)
@MainActor
public final class WorkspaceViewModel: ObservableObject, ConversationWorkspaceHandling {
    // MARK: - Internal Components
    
    private let coordinator: WorkspaceCoordinator
    private let presentationModel: WorkspacePresentationModel
    private let projection: WorkspaceProjection
    private let stateObserver: WorkspaceStateObserver
    
    // MARK: - Published State (Synced with presentationModel and projection)
    
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
    
    // MARK: - Dependencies (Kept for backward compatibility)
    
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
        presentationModel.workspaceState.rootPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }
    
    var descriptorPaths: [FileID: String] {
        presentationModel.workspaceState.projection?.flattenedPaths ?? [:]
    }
    
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
        
        // Create new components
        let presentation = WorkspacePresentationModel()
        let projection = WorkspaceProjection()
        self.presentationModel = presentation
        self.projection = projection
        
        // Note: DomainErrorAuthority will be injected via ChatUIHost in the future
        // For now, create a temporary one (this will be fixed when ChatUIHost is updated)
        let errorAuthority = DomainErrorAuthority()
        let coordinator = WorkspaceCoordinator(
            workspaceEngine: workspaceEngine,
            conversationEngine: conversationEngine,
            codexService: codexService,
            projectTodosLoader: projectTodosLoader,
            presentationModel: presentation,
            projection: projection,
            errorAuthority: errorAuthority
        )
        self.coordinator = coordinator
        
        let observer = WorkspaceStateObserver(
            workspaceEngine: workspaceEngine,
            presentationModel: presentation,
            projection: projection
        )
        self.stateObserver = observer
        
        // Sync published properties with underlying models
        syncWithUnderlyingModels()
        bindContextSelection()
    }
    
    private func syncWithUnderlyingModels() {
        // Sync presentation model properties
        presentationModel.$selectedNode
            .assign(to: &$selectedNode)
        presentationModel.$rootFileNode
            .assign(to: &$rootFileNode)
        presentationModel.$isLoading
            .assign(to: &$isLoading)
        presentationModel.$filterText
            .assign(to: &$filterText)
        presentationModel.$activeNavigator
            .assign(to: &$activeNavigator)
        presentationModel.$expandedDescriptorIDs
            .assign(to: &$expandedDescriptorIDs)
        presentationModel.$projectTodos
            .assign(to: &$projectTodos)
        presentationModel.$todosError
            .assign(to: &$todosError)
        presentationModel.$activeScope
            .assign(to: &$activeScope)
        presentationModel.$modelChoice
            .assign(to: &$modelChoice)
        presentationModel.$selectedDescriptorID
            .assign(to: &$selectedDescriptorID)
        presentationModel.$workspaceState
            .assign(to: &$workspaceState)
        presentationModel.$watcherError
            .assign(to: &$watcherError)
        
        // Sync projection properties
        projection.$streamingMessages
            .assign(to: &$streamingMessages)
        projection.$lastContextResult
            .assign(to: &$lastContextResult)
        projection.$lastContextSnapshot
            .assign(to: &$lastContextSnapshot)
        
        // Also sync in reverse for user-initiated changes
        $selectedNode
            .dropFirst()
            .sink { [weak self] in self?.presentationModel.selectedNode = $0 }
            .store(in: &cancellables)
        $filterText
            .dropFirst()
            .sink { [weak self] in self?.presentationModel.filterText = $0 }
            .store(in: &cancellables)
        $activeNavigator
            .dropFirst()
            .sink { [weak self] in self?.presentationModel.activeNavigator = $0 }
            .store(in: &cancellables)
        $expandedDescriptorIDs
            .dropFirst()
            .sink { [weak self] in self?.presentationModel.expandedDescriptorIDs = $0 }
            .store(in: &cancellables)
    }

    public func setAlertCenter(_ center: AlertCenter) {
        guard alertCenter == nil else { return }
        alertCenter = center
    }
    
    // MARK: - ConversationWorkspaceHandling Protocol
    
    public func sendMessage(_ text: String, for conversation: Conversation) async {
        await coordinator.sendMessage(text, for: conversation)
    }
    
    public func askCodex(_ text: String, for conversation: Conversation) async -> Conversation {
        await coordinator.askCodex(text, for: conversation)
    }
    
    public func setContextScope(_ scope: ContextScopeChoice) {
        coordinator.setContextScope(scope)
    }
    
    public func setModelChoice(_ model: ModelChoice) {
        coordinator.setModelChoice(model)
    }
    
    public func canAskCodex() -> Bool {
        coordinator.canAskCodex()
    }
    
    // MARK: - Streaming Publisher Access
    
    public var streamingPublisher: AnyPublisher<(UUID, String?), Never> {
        projection.streamingPublisher
    }
}
