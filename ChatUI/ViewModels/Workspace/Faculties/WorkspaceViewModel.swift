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
import CoreEngine
import AppAdapters

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
    @Published var selectedURL: URL? {
        didSet {
            updateSelectedNode()
        }
    }
    @Published var rootDirectory: URL {
        didSet {
            handleRootDirectoryChange()
        }
    }
    @Published var filterText: String = ""
    @Published var activeNavigator: NavigatorMode = .project
    @Published var expandedURLs: Set<URL> = []
    @Published var isLoading: Bool = false
    @Published var rootFileNode: FileNode?
    @Published var projectTodos: ProjectTodos = .empty
    @Published var todosError: String?
    @Published private var streamingMessages: [UUID: String] = [:]
    @Published private(set) var lastContextResult: ContextBuildResult?
    
    // MARK: - Dependencies (Services)
    
    private let workspaceEngine: WorkspaceEngine
    private let conversationEngine: ConversationEngineLive<AnyCodexClient, FileStoreConversationPersistence>
    private var eventStream: FSEventStreamRef?
    private var alertCenter: AlertCenter?
    private let logger = Logger.persistence
    private let sentinelDirectoryPath = URL(fileURLWithPath: "/").path
    
    // MARK: - Private State
    
    private var urlToConversationId: [URL: UUID] = [:]
    private var isReloadingFromWatcher = false
    
    // MARK: - Initialization
    
    init(
        workspaceEngine: WorkspaceEngine,
        conversationEngine: ConversationEngineLive<AnyCodexClient, FileStoreConversationPersistence>,
        alertCenter: AlertCenter? = nil
    ) {
        self.workspaceEngine = workspaceEngine
        self.conversationEngine = conversationEngine
        self.alertCenter = alertCenter
        
        // FIX 3: Use sentinel value that does NOT trigger file tree loading
        // Root directory will be set when a real project is opened
        self.rootDirectory = URL(fileURLWithPath: "/")
        self.rootFileNode = nil
    }
    

    func setAlertCenter(_ center: AlertCenter) {
        guard alertCenter == nil else { return }
        alertCenter = center
    }
    
    // MARK: - Public Methods (State Mutations)
    
    func setRootDirectory(_ url: URL) {
        rootDirectory = url
    }
    
    func setSelectedURL(_ url: URL?) {
        selectedURL = url
        Task { try? await workspaceEngine.select(path: url?.path) }
    }

    func streamingText(for conversationID: UUID) -> String {
        streamingMessages[conversationID] ?? ""
    }

    func publishFileBrowserError(_ error: Error) {
        handleFileSystemError(error, fallbackTitle: "Failed to Read Folder")
    }
    
    // MARK: - Private State Management
    
    private func handleRootDirectoryChange() {
        stopWatchingRoot()
        guard rootDirectory.path != sentinelDirectoryPath else {
            projectTodos = .empty
            todosError = nil
            rootFileNode = nil
            selectedURL = nil
            selectedNode = nil
            return
        }

        loadProjectTodos()

        Task { @MainActor [weak self] in
            guard let self else { return }
            isLoading = true
            defer { isLoading = false }
            do {
                _ = try await workspaceEngine.openWorkspace(rootPath: rootDirectory.path)
                let loaded = await loadFileTree(preserveSelection: false)
                if loaded {
                    startWatchingRoot()
                }
            } catch {
                handleFileSystemError(error, fallbackTitle: "Failed to Load Project")
                rootFileNode = nil
            }
        }
    }
    
    private func updateSelectedNode() {
        guard let url = selectedURL else {
            selectedNode = nil
            return
        }

        // Try to find node in loaded tree
        if let root = rootFileNode,
           let node = root.findNode(withURL: url) {
            selectedNode = node
        } else {
            // Fallback: create standalone node
            selectedNode = FileNode.from(url: url, includeParent: false)
        }
    }

    /// Rebuild file tree; optionally preserve current selection.
    @discardableResult
    private func loadFileTree(preserveSelection: Bool) async -> Bool {
        guard rootDirectory.path != sentinelDirectoryPath else {
            stopWatchingRoot()
            return false
        }

        let previousSelection = preserveSelection ? selectedURL : nil
        if !preserveSelection {
            selectedURL = nil
            selectedNode = nil
            expandedURLs.removeAll()
        }

        do {
            logger.debug("Loading workspace tree for \(self.rootDirectory.path, privacy: .private)")
            let descriptors = try await workspaceEngine.refresh()
            guard let tree = FileNode.fromDescriptors(descriptors, rootPath: rootDirectory.path) else {
                throw WorkspaceViewModelError.unreadableProject(rootDirectory.path)
            }
            rootFileNode = tree
        } catch {
            handleFileSystemError(error, fallbackTitle: "Failed to Load Project")
            rootFileNode = nil
            return false
        }

        if preserveSelection,
           let saved = previousSelection,
           FileManager.default.fileExists(atPath: saved.path) {
            selectedURL = saved
        }

        if !preserveSelection {
            if let saved = lastSelectionFromPreferences(for: rootDirectory) {
                selectedURL = saved
            }
        }

        return true
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.stopWatchingRoot()
        }
    }

    private func startWatchingRoot() {
        stopWatchingRoot()
        guard rootDirectory.path != sentinelDirectoryPath else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [rootDirectory.path] as CFArray
        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, _, _, _, _ in
                guard let info else { return }
                let viewModel = Unmanaged<WorkspaceViewModel>.fromOpaque(info).takeUnretainedValue()
                viewModel.handleFileSystemEvent()
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    private func stopWatchingRoot() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    private func handleFileSystemEvent() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if isReloadingFromWatcher { return }
            isReloadingFromWatcher = true
            _ = await loadFileTree(preserveSelection: true)
            isReloadingFromWatcher = false
        }
    }

    /// Selection persistence handled by WorkspaceEngine; lookup helper for UI.
    private func lastSelectionFromPreferences(for root: URL) -> URL? {
        workspaceEngine.state().lastPersistedSelection.map { URL(fileURLWithPath: $0) }
    }
    
    // MARK: - Context Preferences
    
    func isPathIncludedInContext(_ url: URL) -> Bool {
        guard rootDirectory.path != sentinelDirectoryPath else { return true }
        let prefs = workspaceEngine.state().contextPreferences
        let path = url.path
        if prefs.excludedPaths.contains(path) { return false }
        if prefs.includedPaths.isEmpty { return true }
        return prefs.includedPaths.contains(path)
    }
    
    func setContextInclusion(_ include: Bool, for url: URL) {
        guard rootDirectory.path != sentinelDirectoryPath else { return }
        Task {
            _ = try? await workspaceEngine.setContextInclusion(path: url.path, included: include)
        }
    }
    
    private func currentContextPreferences() -> ContextPreferences? {
        let prefs = workspaceEngine.state().contextPreferences
        return ContextPreferences(
            includedPaths: prefs.includedPaths,
            excludedPaths: prefs.excludedPaths,
            lastFocusedFilePath: prefs.lastFocusedFilePath
        )
    }
    
    // MARK: - UI State Methods
    
    func toggleExpanded(_ url: URL) {
        if expandedURLs.contains(url) {
            expandedURLs.remove(url)
        } else {
            expandedURLs.insert(url)
        }
    }
    
    func isExpanded(_ url: URL) -> Bool {
        expandedURLs.contains(url)
    }

    
    // MARK: - Conversation Management (Pure Accessor + Async Ensurer)
    
    /// Get conversation for URL (pure accessor - safe during view rendering)
    /// Returns existing conversation or temporary placeholder - NEVER mutates
    func conversation(for url: URL) -> Conversation {
        if let existing = conversationEngine.conversation(for: url) {
            return existing
        }
        return Conversation(contextFilePaths: [url.path])
    }
    
    /// Ensure conversation exists (side-effecting - must be called from async context)
    /// This should be called when a conversation is actually needed, not during view rendering
    @MainActor
    func ensureConversation(for url: URL) async {
        do {
            let convo = try await conversationEngine.ensureConversation(for: url)
            urlToConversationId[url] = convo.id
        } catch {
            let wrapped = WorkspaceViewModelError.conversationEnsureFailed(error)
            logger.error("Failed to ensure conversation: \(error.localizedDescription, privacy: .public)")
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
            let (updatedConversation, contextResult) = try await conversationEngine.sendMessage(
                text,
                in: conversation,
                contextURL: selectedNode?.path,
                onStream: ({ [weak self] event in
                    guard let self = self else { return }
                    Task { @MainActor in
                        switch event {
                        case .context(let context):
                            self.lastContextResult = context
                        case .model(let chunk):
                            switch chunk {
                            case .token(let token):
                            let current = self.streamingMessages[conversation.id] ?? ""
                            self.streamingMessages[conversation.id] = current + token
                            case .output(let response):
                                self.streamingMessages[conversation.id] = response.content
                            case .done:
                                break
                            }
                        }
                    }
                } as ((ConversationStreamEvent) -> Void)?)
            )
            
            if let url = updatedConversation.contextURL ?? updatedConversation.contextFilePaths.first.map({ URL(fileURLWithPath: $0) }) {
                urlToConversationId[url] = updatedConversation.id
            }
            lastContextResult = contextResult
            
        } catch {
            let wrapped = WorkspaceViewModelError.conversationEnsureFailed(error)
            logger.error("Failed to send message: \(error.localizedDescription, privacy: .public)")
            alertCenter?.publish(wrapped, fallbackTitle: "Conversation Error")
            lastContextResult = nil
        }
    }

    // MARK: - Ontology Todos Loading
    
    private func loadProjectTodos() {
        guard rootDirectory.path != sentinelDirectoryPath else {
            projectTodos = .empty
            todosError = nil
            return
        }
        
        let todosURL = rootDirectory.appendingPathComponent("ProjectTodos.ent.json")
        guard FileManager.default.fileExists(atPath: todosURL.path) else {
            projectTodos = .empty
            todosError = nil
            return
        }
        
        do {
            let data = try Data(contentsOf: todosURL)
            let decoder = JSONDecoder()
            projectTodos = try decoder.decode(ProjectTodos.self, from: data)
            todosError = nil
        } catch {
            projectTodos = .empty
            todosError = "Failed to load ProjectTodos.ent.json: \(error.localizedDescription)"
        }
    }

    private func handleFileSystemError(_ error: Error, fallbackTitle: String) {
        logger.error("Workspace error: \(error.localizedDescription, privacy: .public)")
        alertCenter?.publish(error, fallbackTitle: fallbackTitle)
    }
}
