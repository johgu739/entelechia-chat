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
    
    // MARK: - Internal State
    
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Derived State
    
    public var rootDirectory: URL? {
        projection.workspaceState.rootPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }
    
    var descriptorPaths: [FileID: String] {
        projection.workspaceState.projection?.flattenedPaths ?? [:]
    }
    
    // MARK: - Initialization
    
    public init(
        workspaceEngine: WorkspaceEngine,
        conversationEngine: ConversationStreaming,
        projectTodosLoader: ProjectTodosLoading,
        codexService: CodexQuerying = NullCodexQuerying(),
        domainErrorAuthority: DomainErrorAuthority,
        contextSelection: ContextSelectionState = ContextSelectionState()
    ) {
        // Create new components
        let presentation = WorkspacePresentationModel()
        let projection = WorkspaceProjection()
        self.presentationModel = presentation
        self.projection = projection
        
        let coordinator = WorkspaceCoordinator(
            workspaceEngine: workspaceEngine,
            conversationEngine: conversationEngine,
            codexService: codexService,
            projectTodosLoader: projectTodosLoader,
            presentationModel: presentation,
            projection: projection,
            errorAuthority: domainErrorAuthority
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
        bindContextSelection(contextSelection)
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
        projection.$workspaceState
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
    
    private func bindContextSelection(_ contextSelection: ContextSelectionState) {
        contextSelection.$scopeChoice
            .sink { [weak self] (choice: ContextScopeChoice) in
                guard let self else { return }
                self.activeScope = choice
                self.coordinator.setContextScope(choice)
            }
            .store(in: &cancellables)
        
        contextSelection.$modelChoice
            .sink { [weak self] (choice: ModelChoice) in
                guard let self else { return }
                self.modelChoice = choice
                self.coordinator.setModelChoice(choice)
            }
            .store(in: &cancellables)
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
    
    // MARK: - Public API (Thin Delegation)
    
    public func setRootDirectory(_ url: URL) {
        Task { await coordinator.openWorkspace(at: url) }
    }
    
    public func setSelectedURL(_ url: URL?) {
        guard let url else {
            Task { await coordinator.selectPath(nil) }
            return
        }
        if let descriptorID = descriptorPaths.first(where: { $0.value == url.path })?.key {
            setSelectedDescriptorID(descriptorID)
            return
        }
        Task { await coordinator.selectPath(url) }
    }
    
    public func setSelectedDescriptorID(_ id: FileID?) {
        guard let id else {
            Task { await coordinator.selectPath(nil) }
            return
        }
        if let path = descriptorPaths[id] {
            Task { await coordinator.selectPath(URL(fileURLWithPath: path)) }
        }
    }
    
    public func toggleExpanded(descriptorID: FileID) {
        coordinator.toggleExpanded(descriptorID: descriptorID)
    }
    
    public func isExpanded(descriptorID: FileID) -> Bool {
        coordinator.isExpanded(descriptorID: descriptorID)
    }
    
    public func streamingText(for conversationID: UUID) -> String {
        projection.streamingMessages[conversationID] ?? ""
    }
    
    public func url(for descriptorID: FileID) -> URL? {
        coordinator.url(for: descriptorID)
    }
    
    public func publishFileBrowserError(_ error: Error) {
        coordinator.publishFileBrowserError(error)
    }
    
    public func conversation(for url: URL) async -> Conversation {
        await coordinator.conversation(for: url)
    }
    
    public func conversation(forDescriptorID descriptorID: FileID) async -> Conversation? {
        await coordinator.conversation(forDescriptorID: descriptorID)
    }
    
    public func ensureConversation(for url: URL) async {
        await coordinator.ensureConversation(for: url)
    }
    
    public func ensureConversation(forDescriptorID descriptorID: FileID) async {
        await coordinator.ensureConversation(forDescriptorID: descriptorID)
    }
    
    public func isPathIncludedInContext(_ url: URL) -> Bool {
        coordinator.isPathIncludedInContext(url)
    }
    
    public func setContextInclusion(_ include: Bool, for url: URL) {
        coordinator.setContextInclusion(include, for: url)
    }
    
    public func contextForMessage(_ id: UUID) -> ContextBuildResult? {
        coordinator.contextForMessage(id)
    }
}
