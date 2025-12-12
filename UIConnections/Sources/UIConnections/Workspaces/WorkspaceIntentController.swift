import Foundation
import Combine
import AppCoreEngine
import UIContracts

/// Intent controller for workspace interactions (sole mutation boundary).
/// Owns all workspace ViewModels and exposes derived ViewState structs.
/// All mutations flow through handle(_ intent:) method.
@MainActor
public final class WorkspaceIntentController: ObservableObject {
    // MARK: - Private ViewModels
    
    private let stateViewModel: WorkspaceStateViewModel
    private let activityViewModel: WorkspaceActivityViewModel
    private let bindingViewModel: WorkspaceConversationBindingViewModel
    private let presentationViewModel: WorkspacePresentationViewModel
    private let contextPresentationViewModel: ContextPresentationViewModel
    private let filePreviewViewModel: FilePreviewViewModel
    private let fileStatsViewModel: FileStatsViewModel
    private let folderStatsViewModel: FolderStatsViewModel
    
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Computed ViewState (single source of truth: ViewModels)
    
    /// ViewState is computed from ViewModels (single source of truth).
    public var workspaceState: UIContracts.WorkspaceUIViewState {
        Self.deriveWorkspaceViewState(from: stateViewModel, activityViewModel: activityViewModel)
    }
    
    public var contextState: UIContracts.ContextViewState {
        Self.deriveContextViewState(
            from: bindingViewModel,
            contextPresentation: contextPresentationViewModel
        )
    }
    
    public var presentationState: UIContracts.PresentationViewState {
        Self.derivePresentationViewState(from: presentationViewModel)
    }
    
    // MARK: - Initialization
    
    public init(
        stateViewModel: WorkspaceStateViewModel,
        activityViewModel: WorkspaceActivityViewModel,
        bindingViewModel: WorkspaceConversationBindingViewModel,
        presentationViewModel: WorkspacePresentationViewModel,
        contextPresentationViewModel: ContextPresentationViewModel,
        filePreviewViewModel: FilePreviewViewModel,
        fileStatsViewModel: FileStatsViewModel,
        folderStatsViewModel: FolderStatsViewModel
    ) {
        self.stateViewModel = stateViewModel
        self.activityViewModel = activityViewModel
        self.bindingViewModel = bindingViewModel
        self.presentationViewModel = presentationViewModel
        self.contextPresentationViewModel = contextPresentationViewModel
        self.filePreviewViewModel = filePreviewViewModel
        self.fileStatsViewModel = fileStatsViewModel
        self.folderStatsViewModel = folderStatsViewModel
        
        observeViewModels()
    }
    
    // MARK: - Intent Handling
    
    /// Handle intent - the sole mutation boundary for workspace state.
    public func handle(_ intent: UIContracts.WorkspaceIntent) {
        switch intent {
        case .selectNode(let node):
            // Selection is handled through descriptor ID
            // node is UIContracts.FileNode?, need to extract descriptorID
            if let descriptorID = node?.descriptorID {
                let engineFileID = AppCoreEngine.FileID(descriptorID.rawValue)
                Task {
                    await activityViewModel.selectDescriptorID(engineFileID)
                }
            } else {
                Task {
                    await activityViewModel.selectPath(nil)
                }
            }
            // ViewState is computed, observation will trigger objectWillChange
            
        case .selectDescriptorID(let descriptorID):
            // Convert UIContracts.FileID to AppCoreEngine.FileID
            let engineFileID = AppCoreEngine.FileID(descriptorID.rawValue)
            Task {
                await activityViewModel.selectDescriptorID(engineFileID)
            }
            // ViewState is computed, observation will trigger objectWillChange
            
        case .setContextInclusion(let include, let url):
            activityViewModel.setContextInclusion(include, for: url)
            // ViewState is computed, observation will trigger objectWillChange
            
        case .loadFilePreview(let url):
            Task {
                await filePreviewViewModel.loadPreview(for: url)
            }
            // File preview state is not part of main ViewState, handled separately
            
        case .loadFileStats(let url):
            Task {
                await fileStatsViewModel.loadStats(for: url)
            }
            // File stats state is not part of main ViewState, handled separately
            
        case .loadFolderStats(let url):
            Task {
                await folderStatsViewModel.loadStats(for: url)
            }
            // Folder stats state is not part of main ViewState, handled separately
            
        case .clearFilePreview:
            filePreviewViewModel.clear()
            
        case .clearFileStats:
            fileStatsViewModel.clear()
            
        case .clearFolderStats:
            folderStatsViewModel.clear()
            
        case .clearBanner:
            contextPresentationViewModel.clearBanner()
            // ViewState is computed, observation will trigger objectWillChange
            
        case .toggleExpanded(let descriptorID):
            // Convert UIContracts.FileID to AppCoreEngine.FileID
            let engineFileID = AppCoreEngine.FileID(descriptorID.rawValue)
            presentationViewModel.toggleExpanded(descriptorID: engineFileID)
            // ViewState is computed, observation will trigger objectWillChange
            
        case .setActiveNavigator(let mode):
            presentationViewModel.activeNavigator = mode
            // ViewState is computed, observation will trigger objectWillChange
            
        case .setFilterText(let text):
            presentationViewModel.filterText = text
            // ViewState is computed, observation will trigger objectWillChange
            
        case .clearExpanded:
            presentationViewModel.clearExpanded()
            // ViewState is computed, observation will trigger objectWillChange
        }
    }
    
    // MARK: - ViewState Accessors
    
    /// Get file preview state (for inspector)
    public var filePreviewState: (content: String?, isLoading: Bool, error: Error?) {
        (filePreviewViewModel.content, filePreviewViewModel.isLoading, filePreviewViewModel.error)
    }
    
    /// Get file stats state (for inspector)
    public var fileStatsState: (size: Int64?, lineCount: Int?, tokenEstimate: Int?, isLoading: Bool) {
        (fileStatsViewModel.size, fileStatsViewModel.lineCount, fileStatsViewModel.tokenEstimate, fileStatsViewModel.isLoading)
    }
    
    /// Get folder stats state (for inspector)
    public var folderStatsState: (stats: UIContracts.FolderStats?, isLoading: Bool) {
        if let stats = folderStatsViewModel.stats {
            return (mapFolderStats(stats), folderStatsViewModel.isLoading)
        }
        return (nil, folderStatsViewModel.isLoading)
    }
    
    /// Query if a path is included in context
    public func isPathIncludedInContext(_ url: URL) -> Bool {
        bindingViewModel.isPathIncludedInContext(url)
    }
    
    // MARK: - Private Observation
    
    private func observeViewModels() {
        // Observe workspace state changes and publish objectWillChange (ViewState is computed)
        stateViewModel.$rootFileNode
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        stateViewModel.$selectedNode
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        stateViewModel.$selectedDescriptorID
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Observe activity state changes
        activityViewModel.$projectTodos
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        activityViewModel.$todosError
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Observe context state changes
        bindingViewModel.$lastContextSnapshot
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        bindingViewModel.$lastContextResult
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        bindingViewModel.$streamingMessages
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        contextPresentationViewModel.$bannerMessage
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Observe presentation state changes
        presentationViewModel.$activeNavigator
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        presentationViewModel.$filterText
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        presentationViewModel.$expandedDescriptorIDs
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - ViewState Derivation
    
    private static func deriveWorkspaceViewState(
        from stateViewModel: WorkspaceStateViewModel,
        activityViewModel: WorkspaceActivityViewModel
    ) -> UIContracts.WorkspaceUIViewState {
        UIContracts.WorkspaceUIViewState(
            selectedNode: mapFileNode(stateViewModel.selectedNode),
            selectedDescriptorID: mapFileID(stateViewModel.selectedDescriptorID),
            rootFileNode: mapFileNode(stateViewModel.rootFileNode),
            rootDirectory: stateViewModel.rootDirectory,
            projectTodos: mapProjectTodos(activityViewModel.projectTodos),
            todosErrorDescription: activityViewModel.todosError?.localizedDescription
        )
    }
    
    private static func deriveContextViewState(
        from bindingViewModel: WorkspaceConversationBindingViewModel,
        contextPresentation: ContextPresentationViewModel
    ) -> UIContracts.ContextViewState {
        UIContracts.ContextViewState(
            lastContextSnapshot: mapContextSnapshot(bindingViewModel.lastContextSnapshot),
            lastContextResult: mapContextBuildResult(bindingViewModel.lastContextResult),
            streamingMessages: bindingViewModel.streamingMessages,
            bannerMessage: contextPresentation.bannerMessage
        )
    }
    
    private static func derivePresentationViewState(from viewModel: WorkspacePresentationViewModel) -> UIContracts.PresentationViewState {
        UIContracts.PresentationViewState(
            activeNavigator: viewModel.activeNavigator,
            filterText: viewModel.filterText,
            expandedDescriptorIDs: Set(viewModel.expandedDescriptorIDs.map { mapFileID($0) })
        )
    }
    
    // MARK: - Mapping Functions
    
    private static func mapFileNode(_ node: UIConnections.FileNode?) -> UIContracts.FileNode? {
        guard let node = node else { return nil }
        return UIContracts.FileNode(
            id: node.id,
            descriptorID: mapFileID(node.descriptorID),
            name: node.name,
            path: node.path,
            children: node.children?.compactMap { mapFileNode($0) },
            icon: node.icon,
            isParentDirectory: node.isParentDirectory,
            isDirectory: node.isDirectory
        )
    }
    
    private static func mapFileID(_ id: AppCoreEngine.FileID?) -> UIContracts.FileID? {
        guard let id = id else { return nil }
        return UIContracts.FileID(id.rawValue)
    }
    
    private static func mapFileID(_ id: AppCoreEngine.FileID) -> UIContracts.FileID {
        UIContracts.FileID(id.rawValue)
    }
    
    private static func mapProjectTodos(_ todos: AppCoreEngine.ProjectTodos) -> UIContracts.ProjectTodos {
        UIContracts.ProjectTodos(
            generatedAt: todos.generatedAt,
            missingHeaders: todos.missingHeaders,
            missingFolderTelos: todos.missingFolderTelos,
            filesWithIncompleteHeaders: todos.filesWithIncompleteHeaders,
            foldersWithIncompleteTelos: todos.foldersWithIncompleteTelos,
            allTodos: todos.allTodos
        )
    }
    
    private static func mapContextSnapshot(_ snapshot: UIConnections.ContextSnapshot?) -> UIContracts.ContextSnapshot? {
        guard let snapshot = snapshot else { return nil }
        return UIContracts.ContextSnapshot(
            scope: mapContextScopeChoice(snapshot.scope),
            snapshotHash: snapshot.snapshotHash,
            segments: snapshot.segments.map { mapContextSegmentDescriptor($0) },
            includedFiles: snapshot.includedFiles.map { mapContextFileDescriptor($0) },
            truncatedFiles: snapshot.truncatedFiles.map { mapContextFileDescriptor($0) },
            excludedFiles: snapshot.excludedFiles.map { mapContextFileDescriptor($0) },
            totalTokens: snapshot.totalTokens,
            totalBytes: snapshot.totalBytes
        )
    }
    
    private static func mapContextSegmentDescriptor(_ descriptor: UIConnections.ContextSegmentDescriptor) -> UIContracts.ContextSegmentDescriptor {
        UIContracts.ContextSegmentDescriptor(
            totalTokens: descriptor.totalTokens,
            totalBytes: descriptor.totalBytes,
            files: descriptor.files.map { mapContextFileDescriptor($0) }
        )
    }
    
    private static func mapContextFileDescriptor(_ descriptor: UIConnections.ContextFileDescriptor) -> UIContracts.ContextFileDescriptor {
        UIContracts.ContextFileDescriptor(
            path: descriptor.path,
            language: descriptor.language,
            size: descriptor.size,
            hash: descriptor.hash,
            isIncluded: descriptor.isIncluded,
            isTruncated: descriptor.isTruncated
        )
    }
    
    private static func mapContextBuildResult(_ result: AppCoreEngine.ContextBuildResult?) -> UIContracts.ContextBuildResult? {
        guard let result = result else { return nil }
        return UIContracts.ContextBuildResult(
            attachments: result.attachments.map { mapLoadedFileView($0) },
            truncatedFiles: result.truncatedFiles.map { mapLoadedFileView($0) },
            excludedFiles: result.excludedFiles.map { mapContextExclusionView($0) },
            totalBytes: result.totalBytes,
            totalTokens: result.totalTokens,
            budget: mapContextBudgetView(result.budget)
        )
    }
    
    private static func mapLoadedFileView(_ file: AppCoreEngine.LoadedFile) -> UIContracts.LoadedFileView {
        UIContracts.LoadedFileView(
            name: file.name,
            url: file.url,
            byteCount: file.byteCount,
            tokenEstimate: file.tokenEstimate,
            contextNote: file.contextNote
        )
    }
    
    private static func mapContextExclusionView(_ exclusion: AppCoreEngine.ContextExclusion) -> UIContracts.ContextExclusionView {
        UIContracts.ContextExclusionView(
            id: exclusion.id,
            file: mapLoadedFileView(exclusion.file),
            reason: mapContextExclusionReasonView(exclusion.reason)
        )
    }
    
    private static func mapContextExclusionReasonView(_ reason: AppCoreEngine.ContextExclusionReason) -> UIContracts.ContextExclusionReasonView {
        switch reason {
        case .exceedsPerFileBytes(let limit):
            return .exceedsPerFileBytes(limit: limit)
        case .exceedsPerFileTokens(let limit):
            return .exceedsPerFileTokens(limit: limit)
        case .exceedsTotalBytes(let limit):
            return .exceedsTotalBytes(limit: limit)
        case .exceedsTotalTokens(let limit):
            return .exceedsTotalTokens(limit: limit)
        }
    }
    
    private static func mapContextBudgetView(_ budget: AppCoreEngine.ContextBudget) -> UIContracts.ContextBudgetView {
        UIContracts.ContextBudgetView(
            maxPerFileBytes: budget.maxPerFileBytes,
            maxPerFileTokens: budget.maxPerFileTokens,
            maxTotalBytes: budget.maxTotalBytes,
            maxTotalTokens: budget.maxTotalTokens
        )
    }
    
    private static func mapContextScopeChoice(_ choice: UIConnections.ContextScopeChoice) -> UIContracts.ContextScopeChoice {
        UIContracts.ContextScopeChoice(rawValue: choice.rawValue) ?? .selection
    }
    
    private func mapFolderStats(_ stats: FileMetadataViewModel.FolderStats) -> UIContracts.FolderStats {
        UIContracts.FolderStats(
            totalFiles: stats.totalFiles,
            totalFolders: stats.totalFolders,
            totalSize: stats.totalSize,
            totalLines: stats.totalLines,
            totalTokens: stats.totalTokens
        )
    }
}

