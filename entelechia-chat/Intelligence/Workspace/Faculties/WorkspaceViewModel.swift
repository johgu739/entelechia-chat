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
    
    // MARK: - Dependencies (Services)
    
    private let fileSystemService: WorkspaceFileSystemService
    private let assistant: CodeAssistant
    private var conversationService: ConversationService?
    var conversationStore: ConversationStore!
    private var projectStore: ProjectStore?
    private var eventStream: FSEventStreamRef?
    
    // MARK: - Private State
    
    private var urlToConversationId: [URL: UUID] = [:]
    private var isReloadingFromWatcher = false
    
    // MARK: - Initialization
    
    init(
        fileSystemService: WorkspaceFileSystemService,
        assistant: CodeAssistant,
        conversationStore: ConversationStore? = nil
    ) {
        self.fileSystemService = fileSystemService
        self.assistant = assistant
        
        // FIX 3: Use sentinel value that does NOT trigger file tree loading
        // Root directory will be set when a real project is opened
        self.rootDirectory = URL(fileURLWithPath: "/")
        self.rootFileNode = nil
        
        // Set conversation store if provided
        if let store = conversationStore {
            self.conversationStore = store
            // Load conversations - if database is corrupted, crash
            do {
                try store.loadAll()
            } catch {
                fatalError("❌ Failed to load conversations: \(error.localizedDescription). This is a fatal error - database must be valid.")
            }
            // Initialize conversation service with dependencies
            self.conversationService = ConversationService(
                assistant: assistant,
                conversationStore: store,
                fileContentService: FileContentService.shared
            )
        }
    }
    
    /// Set conversation store (called from MainView with environment object)
    func setConversationStore(_ store: ConversationStore) {
        guard conversationStore == nil else { return }
        self.conversationStore = store
        
        // Load conversations - if database is corrupted, crash
        do {
            try store.loadAll()
        } catch {
            fatalError("❌ Failed to load conversations: \(error.localizedDescription). This is a fatal error - database must be valid.")
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
    
    // MARK: - Public Methods (State Mutations)
    
    func setRootDirectory(_ url: URL) {
        rootDirectory = url
    }
    
    func setSelectedURL(_ url: URL?) {
        selectedURL = url
        persistSelection()
    }
    
    // MARK: - Private State Management
    
    private func handleRootDirectoryChange() {
        stopWatchingRoot()
        loadProjectTodos()
        loadFileTree(preserveSelection: false)
        startWatchingRoot()
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
    private func loadFileTree(preserveSelection: Bool) {
        // Do not load file tree for sentinel value
        let sentinelPath = URL(fileURLWithPath: "/").path
        guard rootDirectory.path != sentinelPath else {
            print("📁 Workspace skipping sentinel path: \(rootDirectory.path)")
            stopWatchingRoot()
            return
        }

        let previousSelection = preserveSelection ? selectedURL : nil

        print("📁 Workspace loading for: \(rootDirectory.path) (preserveSelection=\(preserveSelection))")
        if !preserveSelection {
            selectedURL = nil
            selectedNode = nil
            expandedURLs.removeAll()
        }

        // Build tree - if this fails, crash with clear error
        guard let tree = fileSystemService.buildTree(for: rootDirectory) else {
            fatalError("❌ Failed to build file tree for project at \(rootDirectory.path). The directory may not exist, be inaccessible, or be corrupted. This is a fatal error - project must be valid.")
        }

        // Validate that tree has content - if directory is empty or inaccessible, crash
        if tree.isDirectory {
            // For directories, we must have children (even if empty array)
            // If children is nil, it means loading failed
            guard let children = tree.children else {
                fatalError("❌ Failed to load directory contents for project at \(rootDirectory.path). The directory may be inaccessible or corrupted. This is a fatal error - project must be readable.")
            }

            // If directory exists but has no children, that's also suspicious for a project root
            if children.isEmpty {
                fatalError("❌ Project directory at \(rootDirectory.path) is empty. A project must contain at least one file or folder. This is a fatal error - project must have content.")
            }

            print("📁 Workspace root node children count: \(children.count)")
        } else {
            // If root is a file (not a directory), that's also invalid for a project
            fatalError("❌ Project path at \(rootDirectory.path) is a file, not a directory. A project must be a directory. This is a fatal error - project must be a directory.")
        }

        rootFileNode = tree

        // Restore last selection if preserving and still valid
        if preserveSelection, let saved = previousSelection, FileManager.default.fileExists(atPath: saved.path) {
            selectedURL = saved
        }

        // Restore last persisted selection when opening project
        if !preserveSelection, let saved = projectStore?.lastSelection(for: rootDirectory) {
            print("📁 Restoring last selection: \(saved.path)")
            selectedURL = saved
        }
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.stopWatchingRoot()
        }
    }

    private func startWatchingRoot() {
        stopWatchingRoot()
        let sentinelPath = URL(fileURLWithPath: "/").path
        guard rootDirectory.path != sentinelPath else { return }

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
        guard let store = projectStore else { return }
        guard let selected = selectedURL else { return }
        let sentinelPath = URL(fileURLWithPath: "/").path
        guard rootDirectory.path != sentinelPath else { return }
        do {
            try store.setLastSelection(selected, for: rootDirectory)
        } catch {
            fatalError("❌ Failed to persist last selection: \(error.localizedDescription). This is a fatal error - project store must be writable.")
        }
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

    
    // MARK: - Conversation Management (Delegates to Service)
    
    func conversation(for url: URL) -> Conversation {
        guard let store = conversationStore else {
            return Conversation(contextFilePaths: [url.path])
        }
        
        // Use conversation service if available, otherwise fallback
        if let service = conversationService {
            return service.conversation(for: url, urlToConversationId: &urlToConversationId)
        }
        
        // Fallback: direct store access
        if let conversationId = urlToConversationId[url],
           let existing = store.conversations.first(where: { $0.id == conversationId }) {
            return existing
        }
        
        let new = Conversation(contextFilePaths: [url.path])
        // If save fails, crash - no silent errors
        do {
            try store.save(new)
        } catch {
            fatalError("❌ Failed to save conversation: \(error.localizedDescription). This is a fatal error - database must be valid.")
        }
        urlToConversationId[url] = new.id
        return new
    }
    
    func sendMessage(_ text: String, for conversation: Conversation) async {
        guard let service = conversationService else {
            print("Error: ConversationService not initialized")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await service.sendMessage(text, in: conversation, contextNode: selectedNode)
            
            // Update URL mapping
            if let url = conversation.contextURL {
                urlToConversationId[url] = conversation.id
            }
        } catch {
            print("Error sending message: \(error.localizedDescription)")
        }
    }

    // MARK: - Ontology Todos Loading
    
    private func loadProjectTodos() {
        let sentinelPath = URL(fileURLWithPath: "/").path
        guard rootDirectory.path != sentinelPath else {
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
}
