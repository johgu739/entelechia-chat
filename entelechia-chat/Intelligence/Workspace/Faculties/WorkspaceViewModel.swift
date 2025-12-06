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
    
    private let fileSystemService: WorkspaceFileSystemService
    private let assistant: CodeAssistant
    private var conversationService: ConversationService?
    var conversationStore: ConversationStore!
    private var projectStore: ProjectStore?
    private var preferencesStore: PreferencesStore?
    private var contextPreferencesStore: ContextPreferencesStore?
    private var eventStream: FSEventStreamRef?
    private var alertCenter: AlertCenter?
    private let logger = Logger.persistence
    private let sentinelDirectoryPath = URL(fileURLWithPath: "/").path
    private let lastSelectionPreferenceKey = "workspace.lastSelection.path"
    
    // MARK: - Private State
    
    private var urlToConversationId: [URL: UUID] = [:]
    private var isReloadingFromWatcher = false
    
    // MARK: - Initialization
    
    init(
        fileSystemService: WorkspaceFileSystemService,
        assistant: CodeAssistant,
        conversationStore: ConversationStore? = nil,
        alertCenter: AlertCenter? = nil
    ) {
        self.fileSystemService = fileSystemService
        self.assistant = assistant
        self.alertCenter = alertCenter
        
        // FIX 3: Use sentinel value that does NOT trigger file tree loading
        // Root directory will be set when a real project is opened
        self.rootDirectory = URL(fileURLWithPath: "/")
        self.rootFileNode = nil
        
        // Set conversation store if provided
        if let store = conversationStore {
            setConversationStore(store)
        }
    }
    
    /// Set conversation store (called from MainView with environment object)
    func setConversationStore(_ store: ConversationStore) {
        guard conversationStore == nil else { return }
        self.conversationStore = store
        
        do {
            try store.loadAll()
        } catch {
            logger.error("Failed to load conversations: \(error.localizedDescription, privacy: .public)")
            alertCenter?.publish(error, fallbackTitle: "Failed to Load Conversations")
            return
        }
        
        // Initialize conversation service with existing assistant
        self.conversationService = ConversationService(
            assistant: assistant,
            conversationStore: store,
            fileContentService: FileContentService.shared
        )
    }

    /// Set project store for persisting per-project UI state (last selection).
    func setProjectStore(_ store: ProjectStore) {
        guard projectStore == nil else { return }
        projectStore = store
    }
    
    func setPreferencesStore(_ store: PreferencesStore) {
        guard preferencesStore == nil else { return }
        preferencesStore = store
    }
    
    func setContextPreferencesStore(_ store: ContextPreferencesStore) {
        guard contextPreferencesStore == nil else { return }
        contextPreferencesStore = store
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
        persistSelection()
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
        if loadFileTree(preserveSelection: false) {
            startWatchingRoot()
        }
    }
    
    private func updateSelectedNode() {
        guard let url = selectedURL else {
            selectedNode = nil
            return
        }
        
        // Try to find node in loaded tree
        if let root = rootFileNode,
           let node = fileSystemService.findNode(withURL: url, in: root) {
            selectedNode = node
        } else {
            // Fallback: create standalone node
            selectedNode = fileSystemService.createFileNode(for: url)
        }
    }

    /// Rebuild file tree; optionally preserve current selection.
    @discardableResult
    private func loadFileTree(preserveSelection: Bool) -> Bool {
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
            let tree = try fileSystemService.buildTree(for: self.rootDirectory)
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
            } else if let saved = projectStore?.lastSelection(for: rootDirectory) {
                // Fallback to legacy storage to avoid data loss during transition
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
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if isReloadingFromWatcher { return }
            isReloadingFromWatcher = true
            loadFileTree(preserveSelection: true)
            isReloadingFromWatcher = false
        }
    }
    /// Persist last selection per project when available.
    private func persistSelection() {
        guard let selected = selectedURL else { return }
        guard rootDirectory.path != sentinelDirectoryPath else { return }
        do {
            if let preferencesStore {
                _ = try preferencesStore.update(for: rootDirectory) { preferences in
                    preferences[lastSelectionPreferenceKey] = .string(selected.path)
                }
            } else if let store = projectStore {
                try store.setLastSelection(selected, for: rootDirectory)
            }
        } catch {
            let wrapped = WorkspaceViewModelError.selectionPersistenceFailed(error)
            logger.error("Failed to persist last selection: \(error.localizedDescription, privacy: .public)")
            alertCenter?.publish(wrapped, fallbackTitle: "Failed to Save Selection")
        }
    }
    
    private func lastSelectionFromPreferences(for root: URL) -> URL? {
        guard let preferencesStore else { return nil }
        let preferences = (try? preferencesStore.load(for: root, strict: false)) ?? .empty
        guard
            let value = preferences[lastSelectionPreferenceKey],
            case let .string(path) = value
        else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
    
    // MARK: - Context Preferences
    
    func isPathIncludedInContext(_ url: URL) -> Bool {
        guard let contextPreferencesStore, rootDirectory.path != sentinelDirectoryPath else { return true }
        let preferences = (try? contextPreferencesStore.load(for: rootDirectory, strict: false)) ?? .empty
        let path = url.path
        
        if preferences.excludedPaths.contains(path) {
            return false
        }
        if preferences.includedPaths.isEmpty {
            return true
        }
        return preferences.includedPaths.contains(path)
    }
    
    func setContextInclusion(_ include: Bool, for url: URL) {
        guard let contextPreferencesStore, rootDirectory.path != sentinelDirectoryPath else { return }
        var preferences = (try? contextPreferencesStore.load(for: rootDirectory, strict: false)) ?? .empty
        let path = url.path
        
        if include {
            preferences.excludedPaths.remove(path)
            preferences.includedPaths.insert(path)
            preferences.lastFocusedFilePath = path
        } else {
            preferences.includedPaths.remove(path)
            preferences.excludedPaths.insert(path)
            preferences.lastFocusedFilePath = path
        }
        
        do {
            try contextPreferencesStore.save(preferences, for: rootDirectory)
        } catch {
            let wrapped = WorkspaceViewModelError.selectionPersistenceFailed(error)
            logger.error("Failed to persist context preferences: \(error.localizedDescription, privacy: .public)")
            alertCenter?.publish(wrapped, fallbackTitle: "Failed to Save Context Preferences")
        }
    }
    
    private func currentContextPreferences() -> ContextPreferences? {
        guard let contextPreferencesStore, rootDirectory.path != sentinelDirectoryPath else { return nil }
        return try? contextPreferencesStore.load(for: rootDirectory, strict: false)
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
        guard let store = conversationStore else {
            return Conversation(contextFilePaths: [url.path])
        }
        
        // Use conversation service if available (pure read - no mutations)
        if let service = conversationService,
           let existing = service.conversation(for: url, urlToConversationId: urlToConversationId) {
            return existing
        }
        
        // Fallback: direct store access (pure read)
        if let conversationId = urlToConversationId[url],
           let existing = store.conversations.first(where: { $0.id == conversationId }) {
            return existing
        }
        
        // Try to find existing by path (pure read)
        if let existing = store.conversations
            .filter({ $0.contextFilePaths.contains(url.path) })
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first {
            return existing
        }
        
        // Return temporary placeholder (will be replaced when ensureConversation completes)
        // This is safe because it doesn't mutate @Published properties
        return Conversation(contextFilePaths: [url.path])
    }
    
    /// Ensure conversation exists (side-effecting - must be called from async context)
    /// This should be called when a conversation is actually needed, not during view rendering
    @MainActor
    func ensureConversation(for url: URL) async {
        guard let service = conversationService else {
            return
        }
        
        do {
            let (_, updatedMapping) = try await service.ensureConversation(for: url, urlToConversationId: urlToConversationId)
            urlToConversationId = updatedMapping
        } catch {
            let wrapped = WorkspaceViewModelError.conversationEnsureFailed(error)
            logger.error("Failed to ensure conversation: \(error.localizedDescription, privacy: .public)")
            alertCenter?.publish(wrapped, fallbackTitle: "Conversation Error")
        }
    }
    
    func sendMessage(_ text: String, for conversation: Conversation) async {
        guard let service = conversationService else { return }
        
        isLoading = true
        streamingMessages[conversation.id] = ""
        defer {
            isLoading = false
            streamingMessages[conversation.id] = nil
        }
        
        do {
            let (updatedConversation, contextResult) = try await service.sendMessage(
                text,
                in: conversation,
                contextNode: selectedNode,
                preferences: currentContextPreferences(),
                onStreamEvent: { [weak self] chunk in
                    guard let self = self else { return }
                    Task { @MainActor in
                        switch chunk {
                        case .token(let token):
                            let current = self.streamingMessages[conversation.id] ?? ""
                            self.streamingMessages[conversation.id] = current + token
                        case .output, .done:
                            self.streamingMessages[conversation.id] = ""
                        }
                    }
                }
            )
            
            if let url = updatedConversation.contextURL {
                urlToConversationId[url] = updatedConversation.id
            }
            lastContextResult = contextResult
            
            await MainActor.run {
                if let store = conversationStore,
                   let index = store.conversations.firstIndex(where: { $0.id == updatedConversation.id }) {
                    store.conversations[index] = updatedConversation
                }
            }
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
