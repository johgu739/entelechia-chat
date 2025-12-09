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
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreServices
import os.log
import AppCoreEngine
import UIConnections

enum WorkspaceViewModelError: LocalizedError {
    case invalidProjectPath(String)
    case unreadableProject(String)
    case emptyProject(String)
    case selectionPersistenceFailed(Error)
    case conversationEnsureFailed(Error)

    var errorDescription: String? {
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

    var failureReason: String? {
        switch self {
        case .selectionPersistenceFailed(let error),
            .conversationEnsureFailed(let error):
            return error.localizedDescription
        default:
            return errorDescription
        }
    }
}

// ProjectTodos is defined in Intelligence/Projects/Models/ProjectTodos.swift
// Since it's in the same app target, no explicit import needed, but ensure file is in target

/// Navigator mode matching Xcode's navigator tabs
enum NavigatorMode: String, CaseIterable {
    case project = "Project"
    case todos = "Ontology TODOs"
    case search = "Search"
    case issues = "Issues"
    case tests = "Tests"
    case reports = "Reports"
    
    var icon: String {
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
class WorkspaceViewModel: ObservableObject {
    // MARK: - Published State (UI State Only)
    
    @Published var selectedNode: FileNode?
    @Published var rootFileNode: FileNode?
    @Published var isLoading: Bool = false
    @Published var filterText: String = ""
    @Published var activeNavigator: NavigatorMode = .project
    @Published var expandedDescriptorIDs: Set<FileID> = []
    @Published var projectTodos: ProjectTodos = .empty
    @Published var todosError: String?
    @Published private var streamingMessages: [UUID: String] = [:]
    @Published private(set) var lastContextResult: ContextBuildResult?
    @Published private(set) var selectedDescriptorID: FileID?
    @Published private var workspaceState: WorkspaceViewState = WorkspaceViewState(
        rootPath: nil,
        selectedDescriptorID: nil,
        selectedPath: nil,
        projection: nil,
        contextInclusions: [:],
        watcherError: nil
    )
    @Published var watcherError: String?
    private var updatesTask: Task<Void, Never>?
    
    // MARK: - Dependencies (Services)
    
    private let workspaceEngine: WorkspaceEngine
    private let conversationEngine: ConversationStreaming
    private let projectTodosLoader: ProjectTodosLoading
    private var alertCenter: AlertCenter?
    private let logger = Logger.persistence
    private let contextErrorSubject = PassthroughSubject<String, Never>()
    
    // MARK: - Derived State
    
    var rootDirectory: URL? {
        workspaceSnapshot.rootPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }
    
    private var descriptorPaths: [FileID: String] {
        workspaceState.projection?.flattenedPaths ?? [:]
    }
    
    // MARK: - Private State
    private var workspaceSnapshot: WorkspaceSnapshot = .empty
    
    // MARK: - Initialization
    
    init(
        workspaceEngine: WorkspaceEngine,
        conversationEngine: ConversationStreaming,
        projectTodosLoader: ProjectTodosLoading,
        alertCenter: AlertCenter? = nil
    ) {
        self.workspaceEngine = workspaceEngine
        self.conversationEngine = conversationEngine
        self.projectTodosLoader = projectTodosLoader
        self.alertCenter = alertCenter
        subscribeToUpdates()
    }
    

    func setAlertCenter(_ center: AlertCenter) {
        guard alertCenter == nil else { return }
        alertCenter = center
    }
    
    // MARK: - Public Methods (State Mutations)
    
    func setRootDirectory(_ url: URL) {
        Task { await openWorkspace(at: url) }
    }
    
    func setSelectedURL(_ url: URL?) {
        guard let url else {
            Task { await selectPath(nil) }
            return
        }
        // Prefer descriptor-based selection when possible.
        if let descriptorID = descriptorPaths.first(where: { $0.value == url.path })?.key {
            setSelectedDescriptorID(descriptorID)
            return
        }
        Task { await selectPath(url) }
    }
    
    /// Preferred selection API: selects by engine descriptor ID.
    func setSelectedDescriptorID(_ id: FileID?) {
        guard let id else {
            Task { await selectPath(nil) }
            return
        }
        if let path = descriptorPaths[id] {
            Task { await selectPath(URL(fileURLWithPath: path)) }
        }
    }

    func streamingText(for conversationID: UUID) -> String {
        streamingMessages[conversationID] ?? ""
    }

    
    var contextErrorPublisher: AnyPublisher<String, Never> {
        contextErrorSubject.eraseToAnyPublisher()
    }
    
    /// Lookup the URL associated with an engine descriptor ID (if known).
    func url(for descriptorID: FileID) -> URL? {
        descriptorPaths[descriptorID].map { URL(fileURLWithPath: $0) }
    }

    func publishFileBrowserError(_ error: Error) {
        handleFileSystemError(error, fallbackTitle: "Failed to Read Folder")
    }
    
    // MARK: - Private State Management
    
    private func openWorkspace(at url: URL) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await withTimeout(seconds: 30) { [self] in
                try await workspaceEngine.openWorkspace(rootPath: url.path)
            }
            applyUpdate(WorkspaceUpdate(snapshot: snapshot, projection: await workspaceEngine.treeProjection(), error: nil))
            loadProjectTodos(for: url)
        } catch let timeout as TimeoutError {
            handleFileSystemError(timeout, fallbackTitle: "Load Timed Out")
            applyUpdate(WorkspaceUpdate(snapshot: .empty, projection: nil, error: nil))
            rootFileNode = nil
        } catch {
            handleFileSystemError(error, fallbackTitle: "Failed to Load Project")
            applyUpdate(WorkspaceUpdate(snapshot: .empty, projection: nil, error: nil))
            rootFileNode = nil
        }
    }
    
    private func selectPath(_ url: URL?) async {
        do {
            let snapshot = try await withTimeout(seconds: 10) { [self] in
                try await workspaceEngine.select(path: url?.path)
            }
            applyUpdate(WorkspaceUpdate(snapshot: snapshot, projection: await workspaceEngine.treeProjection(), error: nil))
        } catch let timeout as TimeoutError {
            handleFileSystemError(timeout, fallbackTitle: "Selection Timed Out")
        } catch {
            handleFileSystemError(error, fallbackTitle: "Failed to Select File")
        }
    }
    
    private func applyUpdate(_ update: WorkspaceUpdate) {
        workspaceSnapshot = update.snapshot
        let previousRoot = workspaceState.rootPath
        let notice: WorkspaceErrorNotice? = {
            guard let err = update.error else { return nil }
            switch err {
            case .watcherUnavailable: return .watcherUnavailable
            case .refreshFailed(let message): return .refreshFailed(message)
            }
        }()
        let mapped = WorkspaceViewStateMapper.map(update: update, watcherError: notice)
        workspaceState = mapped
        if previousRoot != mapped.rootPath {
            expandedDescriptorIDs.removeAll()
            selectedNode = nil
            selectedDescriptorID = nil
        }
        selectedDescriptorID = mapped.selectedDescriptorID
        if let selectedDescriptorID,
           let projection = mapped.projection,
           let node = FileNode.fromProjection(projection).findNode(withDescriptorID: selectedDescriptorID) {
            selectedNode = node
        } else {
            updateSelectedNode()
        }
        if let projection = mapped.projection {
            rootFileNode = FileNode.fromProjection(projection)
        }
        watcherError = mapped.watcherError
    }

    private func applySnapshot(_ snapshot: WorkspaceSnapshot, projection: WorkspaceTreeProjection?) {
        let update = WorkspaceUpdate(snapshot: snapshot, projection: projection, error: nil)
        applyUpdate(update)
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

    private func updateSelectedNode() {
        guard let descriptorID = selectedDescriptorID else {
            selectedNode = nil
            return
        }
        if let node = rootFileNode?.findNode(withDescriptorID: descriptorID) {
            selectedNode = node
        } else {
            selectedNode = nil
        }
    }
    
    // MARK: - Context Preferences
    
    func isPathIncludedInContext(_ url: URL) -> Bool {
        guard workspaceSnapshot.rootPath != nil else { return true }
        let path = url.path
        if let descriptorID = workspaceSnapshot.descriptorPaths.first(where: { $0.value == path })?.key,
           let inclusion = workspaceSnapshot.contextInclusions[descriptorID] {
            switch inclusion {
            case .excluded:
                return false
            case .included:
                return true
            case .neutral:
                return true
            }
        }
        return true
    }
    
    func setContextInclusion(_ include: Bool, for url: URL) {
        guard workspaceSnapshot.rootPath != nil else { return }
        Task {
            if let snapshot = try? await workspaceEngine.setContextInclusion(path: url.path, included: include) {
                let projection = await workspaceEngine.treeProjection()
                await MainActor.run {
                    applySnapshot(snapshot, projection: projection)
                }
            }
        }
    }
    
    // MARK: - UI State Methods
    
    func toggleExpanded(descriptorID: FileID) {
        if expandedDescriptorIDs.contains(descriptorID) {
            expandedDescriptorIDs.remove(descriptorID)
        } else {
            expandedDescriptorIDs.insert(descriptorID)
        }
    }
    
    func isExpanded(descriptorID: FileID) -> Bool {
        expandedDescriptorIDs.contains(descriptorID)
    }

    
    // MARK: - Conversation Management (Pure Accessor + Async Ensurer)
    
    /// Get conversation for URL (pure accessor - safe during view rendering)
    /// Returns existing conversation or temporary placeholder - NEVER mutates
    func conversation(for url: URL) async -> Conversation {
        if let engineConvo = await conversationEngine.conversation(for: url) {
            return engineConvo
        }
        return Conversation(contextFilePaths: [url.path])
    }
    
    /// Preferred accessor: lookup by descriptor ID, falls back to URL if missing.
    func conversation(forDescriptorID descriptorID: FileID) async -> Conversation? {
        if let engineConvo = await conversationEngine.conversation(forDescriptorIDs: [descriptorID]) {
            return engineConvo
        }
        if let url = url(for: descriptorID) {
            return await conversation(for: url)
        }
        return nil
    }
    
    /// Ensure conversation exists (side-effecting - must be called from async context)
    /// This should be called when a conversation is actually needed, not during view rendering
    @MainActor
    func ensureConversation(for url: URL) async {
        do {
            _ = try await conversationEngine.ensureConversation(for: url)
        } catch {
            let wrapped = WorkspaceViewModelError.conversationEnsureFailed(error)
            logger.error("Failed to ensure conversation: \(error.localizedDescription, privacy: .public)")
            alertCenter?.publish(wrapped, fallbackTitle: "Conversation Error")
        }
    }
    
    /// Preferred side-effecting ensure: lookup by descriptor ID, fallback to URL if missing.
    @MainActor
    func ensureConversation(forDescriptorID descriptorID: FileID) async {
        do {
            _ = try await conversationEngine.ensureConversation(forDescriptorIDs: [descriptorID]) { [weak self] id in
                self?.descriptorPaths[id]
            }
        } catch {
            let wrapped = WorkspaceViewModelError.conversationEnsureFailed(error)
            logger.error("Failed to ensure conversation via descriptor: \(error.localizedDescription, privacy: .public)")
            alertCenter?.publish(wrapped, fallbackTitle: "Conversation Error")
        }
    }
    
    func sendMessage(_ text: String, for conversation: Conversation) async {
        isLoading = true
        streamingMessages[conversation.id] = ""
        defer {
            isLoading = false
            streamingMessages[conversation.id] = nil
        }
        
        do {
            // Ensure we have some form of context selection before invoking the engine.
            let hasContextAnchor = !workspaceSnapshot.descriptorPaths.isEmpty
                || workspaceSnapshot.selectedPath != nil
                || workspaceSnapshot.contextPreferences.lastFocusedFilePath != nil
            if !hasContextAnchor {
                let message = "Context load failed: no selection"
                alertCenter?.publish(WorkspaceViewModelError.conversationEnsureFailed(EngineError.contextLoadFailed(message)), fallbackTitle: "Context Error")
                contextErrorSubject.send(message)
                lastContextResult = nil
                return
            }

            var convo = conversation
            // If we have a selected descriptor ID, persist it with the conversation for ID binding.
            if let did = selectedDescriptorID {
                convo.contextDescriptorIDs = [did]
            }
            let contextRequest = ConversationContextRequest(
                snapshot: workspaceSnapshot,
                preferredDescriptorIDs: convo.contextDescriptorIDs,
                fallbackContextURL: selectedNode?.path,
                budget: nil
            )
            let (_, contextResult) = try await withTimeout(seconds: 60) { [self] in
                try await conversationEngine.sendMessage(
                    text,
                    in: convo,
                    context: contextRequest,
                    onStream: ({ [weak self] event in
                        guard let self = self else { return }
                        Task { @MainActor in
                            switch event {
                            case .context(let context):
                                self.lastContextResult = context
                            case .assistantStreaming(let aggregate):
                                self.streamingMessages[conversation.id] = aggregate
                            case .assistantCommitted(_):
                                self.streamingMessages[conversation.id] = nil
                            }
                        }
                    } as ((ConversationDelta) -> Void)?)
                )
            }
            lastContextResult = contextResult
            
        } catch {
            let wrapped = WorkspaceViewModelError.conversationEnsureFailed(error)
            logger.error("Failed to send message: \(error.localizedDescription, privacy: .public)")
            if case EngineError.contextLoadFailed(let message) = error {
                alertCenter?.publish(WorkspaceViewModelError.conversationEnsureFailed(error), fallbackTitle: "Context Load Failed: \(message)")
                contextErrorSubject.send("Context load failed: \(message)")
            } else {
                alertCenter?.publish(wrapped, fallbackTitle: "Conversation Error")
            }
            lastContextResult = nil
        }
    }

    // MARK: - Ontology Todos Loading
    
    private func loadProjectTodos(for root: URL?) {
        guard let root else {
            projectTodos = .empty
            todosError = nil
            return
        }
        Task {
            do {
                let todos = try projectTodosLoader.loadTodos(for: root)
                await MainActor.run {
                    projectTodos = todos
                    todosError = nil
                }
            } catch {
                await MainActor.run {
                    projectTodos = .empty
                    todosError = "Failed to load ProjectTodos.ent.json: \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleFileSystemError(_ error: Error, fallbackTitle: String) {
        logger.error("Workspace error: \(error.localizedDescription, privacy: .public)")
        alertCenter?.publish(error, fallbackTitle: fallbackTitle)
    }
    
    // MARK: - Timeouts
    struct TimeoutError: LocalizedError {
        let seconds: Double
        var errorDescription: String? { "Operation timed out after \(seconds) seconds." }
    }

    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError(seconds: seconds)
            }
            guard let result = try await group.next() else {
                throw TimeoutError(seconds: seconds)
            }
            group.cancelAll()
            return result
        }
    }
}

