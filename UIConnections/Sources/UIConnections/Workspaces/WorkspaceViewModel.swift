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
import UIContracts

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
        scope: UIContracts.WorkspaceScope,
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
    
    // Internal domain types for coordination
    private var internalSelectedNode: FileNode?
    private var internalRootFileNode: FileNode?
    private var internalLastContextResult: AppCoreEngine.ContextBuildResult?
    
    @Published public var selectedNode: UIContracts.FileNode?
    @Published public var rootFileNode: UIContracts.FileNode?
    @Published public var isLoading: Bool = false
    @Published public var filterText: String = ""
    @Published public var activeNavigator: UIContracts.NavigatorMode = .project
    @Published public var expandedDescriptorIDs: Set<UIContracts.FileID> = []
    @Published public var projectTodos: UIContracts.ProjectTodos = .empty
    @Published public var todosError: String?
    @Published var streamingMessages: [UUID: String] = [:]
    @Published public var lastContextResult: UIContracts.UIContextBuildResult?
    @Published public var lastContextSnapshot: UIContracts.ContextSnapshot?
    @Published public var activeScope: UIContracts.ContextScopeChoice = .selection
    @Published public var modelChoice: UIContracts.ModelChoice = .codex
    @Published public var selectedDescriptorID: UIContracts.FileID?
    @Published var workspaceState: UIContracts.WorkspaceViewState = UIContracts.WorkspaceViewState(
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
    
    public func sendMessage(_ text: String, for conversation: UIContracts.UIConversation) async {
        let internalConversation = mapToInternalConversation(conversation)
        await coordinator.sendMessage(text, for: internalConversation)
    }
    
    public func askCodex(_ text: String, for conversation: UIContracts.UIConversation) async -> UIContracts.UIConversation {
        let internalConversation = mapToInternalConversation(conversation)
        let result = await coordinator.askCodex(text, for: internalConversation)
        return mapToUIConversation(result)
    }
    
    public func setContextScope(_ scope: UIContracts.ContextScopeChoice) {
        let internalScope = mapToInternalContextScopeChoice(scope)
        coordinator.setContextScope(internalScope)
    }
    
    public func setModelChoice(_ model: UIContracts.ModelChoice) {
        let internalModel = mapToInternalModelChoice(model)
        coordinator.setModelChoice(internalModel)
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
    
    public func setSelectedDescriptorID(_ id: UIContracts.FileID?) {
        guard let id else {
            Task { await coordinator.selectPath(nil) }
            return
        }
        let internalID = AppCoreEngine.FileID(rawValue: id.rawValue)
        if let path = descriptorPaths[internalID] {
            Task { await coordinator.selectPath(URL(fileURLWithPath: path)) }
        }
    }
    
    public func toggleExpanded(descriptorID: UIContracts.FileID) {
        let internalID = AppCoreEngine.FileID(rawValue: descriptorID.rawValue)
        coordinator.toggleExpanded(descriptorID: internalID)
    }
    
    public func isExpanded(descriptorID: UIContracts.FileID) -> Bool {
        let internalID = AppCoreEngine.FileID(rawValue: descriptorID.rawValue)
        return coordinator.isExpanded(descriptorID: internalID)
    }
    
    public func streamingText(for conversationID: UUID) -> String {
        projection.streamingMessages[conversationID] ?? ""
    }
    
    public func url(for descriptorID: UIContracts.FileID) -> URL? {
        let internalID = AppCoreEngine.FileID(rawValue: descriptorID.rawValue)
        return coordinator.url(for: internalID)
    }
    
    public func publishFileBrowserError(_ error: Error) {
        coordinator.publishFileBrowserError(error)
    }
    
    public func conversation(for url: URL) async -> UIContracts.UIConversation {
        let internalConversation = await coordinator.conversation(for: url)
        return mapToUIConversation(internalConversation)
    }
    
    public func conversation(forDescriptorID descriptorID: UIContracts.FileID) async -> UIContracts.UIConversation? {
        let internalID = AppCoreEngine.FileID(rawValue: descriptorID.rawValue)
        guard let internalConversation = await coordinator.conversation(forDescriptorID: internalID) else {
            return nil
        }
        return mapToUIConversation(internalConversation)
    }
    
    public func ensureConversation(for url: URL) async {
        await coordinator.ensureConversation(for: url)
    }
    
    public func ensureConversation(forDescriptorID descriptorID: UIContracts.FileID) async {
        let internalID = AppCoreEngine.FileID(rawValue: descriptorID.rawValue)
        await coordinator.ensureConversation(forDescriptorID: internalID)
    }
    
    public func isPathIncludedInContext(_ url: URL) -> Bool {
        coordinator.isPathIncludedInContext(url)
    }
    
    public func setContextInclusion(_ include: Bool, for url: URL) {
        coordinator.setContextInclusion(include, for: url)
    }
    
    public func contextForMessage(_ id: UUID) -> UIContracts.UIContextBuildResult? {
        guard let internalResult = coordinator.contextForMessage(id) else {
            return nil
        }
        return mapToUIContextBuildResult(internalResult)
    }
    
    // MARK: - Internal Mapping Helpers
    
    private func mapToUIConversation(_ conversation: AppCoreEngine.Conversation) -> UIContracts.UIConversation {
        UIContracts.UIConversation(
            id: conversation.id,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            messages: conversation.messages.map { mapToUIMessage($0) },
            contextFilePaths: conversation.contextFilePaths,
            contextDescriptorIDs: conversation.contextDescriptorIDs?.map { UIContracts.FileID(rawValue: $0.rawValue) }
        )
    }
    
    private func mapToInternalConversation(_ conversation: UIContracts.UIConversation) -> AppCoreEngine.Conversation {
        AppCoreEngine.Conversation(
            id: conversation.id,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            messages: conversation.messages.map { mapToInternalMessage($0) },
            contextFilePaths: conversation.contextFilePaths,
            contextDescriptorIDs: conversation.contextDescriptorIDs?.map { AppCoreEngine.FileID(rawValue: $0.rawValue) }
        )
    }
    
    private func mapToUIMessage(_ message: AppCoreEngine.Message) -> UIContracts.UIMessage {
        UIContracts.UIMessage(
            id: message.id,
            role: UIContracts.UIMessageRole(rawValue: message.role.rawValue) ?? .user,
            text: message.text,
            createdAt: message.createdAt,
            attachments: message.attachments.map { mapToUIAttachment($0) }
        )
    }
    
    private func mapToInternalMessage(_ message: UIContracts.UIMessage) -> AppCoreEngine.Message {
        AppCoreEngine.Message(
            id: message.id,
            role: AppCoreEngine.MessageRole(rawValue: message.role.rawValue) ?? .user,
            text: message.text,
            createdAt: message.createdAt,
            attachments: message.attachments.map { mapToInternalAttachment($0) }
        )
    }
    
    private func mapToUIAttachment(_ attachment: AppCoreEngine.Attachment) -> UIContracts.UIAttachment {
        switch attachment {
        case .file(let path):
            return .file(path: path)
        case .code(let language, let content):
            return .code(language: language, content: content)
        }
    }
    
    private func mapToInternalAttachment(_ attachment: UIContracts.UIAttachment) -> AppCoreEngine.Attachment {
        switch attachment {
        case .file(let path):
            return .file(path: path)
        case .code(let language, let content):
            return .code(language: language, content: content)
        }
    }
    
    private func mapToUIContextBuildResult(_ result: AppCoreEngine.ContextBuildResult) -> UIContracts.UIContextBuildResult {
        DomainToUIMappers.toUIContextBuildResult(result)
    }
    
    private func mapToInternalContextScopeChoice(_ choice: UIContracts.ContextScopeChoice) -> ContextScopeChoice {
        ContextScopeChoice(rawValue: choice.rawValue) ?? .selection
    }
    
    private func mapToInternalModelChoice(_ choice: UIContracts.ModelChoice) -> ModelChoice {
        ModelChoice(rawValue: choice.rawValue) ?? .codex
    }
}
