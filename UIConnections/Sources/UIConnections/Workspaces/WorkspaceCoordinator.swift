import Foundation
import Combine
import os.log
import AppCoreEngine
import UIContracts

// Protocols are defined in Protocols/CoordinatorProtocols.swift
// WorkspaceCoordinating protocol is imported from that file

/// Coordinator for workspace orchestration.
/// Power: Decisional (orchestrates workflows, makes decisions, coordinates engines)
/// Owns async logic, context building, error handling, and decision-making.
@MainActor
internal final class WorkspaceCoordinator: ConversationWorkspaceHandling, WorkspaceCoordinating {
    // MARK: - Dependencies
    
    private let workspaceEngine: WorkspaceEngine
    private let conversationEngine: ConversationStreaming
    private let codexService: CodexQuerying
    private let projectTodosLoader: ProjectTodosLoading
    private let presentationModel: WorkspacePresentationModel
    private let projection: WorkspaceProjection
    private let errorAuthority: DomainErrorAuthority
    private var stateObserver: WorkspaceStateObserver?
    private let logger = Logger(subsystem: "UIConnections", category: "WorkspaceCoordinator")
    
    // MARK: - Private State
    
    private var workspaceSnapshot: WorkspaceSnapshot = .empty
    private var codexContextByMessageID: [UUID: UIContracts.UIContextBuildResult] = [:]
    
    // MARK: - Detail State Store
    
    /// Store of DetailState instances keyed by descriptor ID.
    /// One DetailState per descriptor, preserved across selection changes.
    private var detailStore: [UIContracts.FileID: DetailState] = [:]
    
    /// Currently active detail identity (nil when no selection).
    private var activeDetailID: UIContracts.FileID?
    
    /// Currently active detail state (derived from store).
    /// Returns stored DetailState for activeDetailID, or .empty if no selection.
    private var activeDetailState: DetailState {
        guard let activeID = activeDetailID,
              let stored = detailStore[activeID] else {
            return .empty
        }
        return stored
    }
    
    // MARK: - Initialization
    
    init(
        workspaceEngine: WorkspaceEngine,
        conversationEngine: ConversationStreaming,
        codexService: CodexQuerying,
        projectTodosLoader: ProjectTodosLoading,
        presentationModel: WorkspacePresentationModel,
        projection: WorkspaceProjection,
        errorAuthority: DomainErrorAuthority,
        stateObserver: WorkspaceStateObserver? = nil
    ) {
        // INVARIANT 4: Observer lifecycle - coordinator must retain exactly one observer
        self.workspaceEngine = workspaceEngine
        self.conversationEngine = conversationEngine
        self.codexService = codexService
        self.projectTodosLoader = projectTodosLoader
        self.presentationModel = presentationModel
        self.projection = projection
        self.errorAuthority = errorAuthority
        self.stateObserver = stateObserver
        // Observer is retained, ensuring single active observer per coordinator
        // Observer may be set after initialization to break circular dependency
    }
    
    /// Set the state observer (called after observer creation to break circular dependency)
    func setStateObserver(_ observer: WorkspaceStateObserver) {
        self.stateObserver = observer
    }
    
    // MARK: - ConversationWorkspaceHandling Protocol
    
    public func sendMessage(_ text: String, for conversation: AppCoreEngine.Conversation) async {
        let correlationID = UUID()
        TeleologicalTracer.shared.trace("WorkspaceCoordinator.sendMessage", power: .decisional, correlationID: correlationID)
        presentationModel.isLoading = true
        guard let activeID = activeDetailID, var activeDetail = detailStore[activeID] else {
            presentationModel.isLoading = false
            handleContextLoadFailure(message: "Context load failed: no selection")
            return
        }
        activeDetail.streamingMessages[conversation.id] = ""
        detailStore[activeID] = activeDetail
        defer {
            presentationModel.isLoading = false
            if var detail = detailStore[activeID] {
                detail.streamingMessages[conversation.id] = nil
                detailStore[activeID] = detail
            }
        }
        
        do {
            guard hasContextAnchor() else {
                handleContextLoadFailure(message: "Context load failed: no selection")
                return
            }

            var convo = conversation
            if let did = activeDetailState.selectedDescriptorID {
                convo.contextDescriptorIDs = [AppCoreEngine.FileID(did.rawValue)]
            }
            let contextRequest = buildContextRequest(for: convo)
            let (_, contextResult) = try await sendMessageWithContext(
                text: text,
                conversation: convo,
                contextRequest: contextRequest
            )
            activeDetail.contextResult = DomainToUIMappers.toUIContextBuildResult(contextResult)
            activeDetail.contextSnapshot = buildContextSnapshot(from: contextResult)
            detailStore[activeID] = activeDetail
            
        } catch {
            handleSendMessageError(error)
        }
    }
    
    public func askCodex(_ text: String, for conversation: AppCoreEngine.Conversation) async -> AppCoreEngine.Conversation {
        let correlationID = UUID()
        TeleologicalTracer.shared.trace("WorkspaceCoordinator.askCodex", power: .decisional, correlationID: correlationID)
        presentationModel.isLoading = true
        guard let activeID = activeDetailID, var activeDetail = detailStore[activeID] else {
            presentationModel.isLoading = false
            errorAuthority.publish(
                EngineError.contextLoadFailed("No selection"),
                context: "Codex Error"
            )
            return conversation
        }
        activeDetail.streamingMessages[conversation.id] = ""
        detailStore[activeID] = activeDetail
        defer {
            presentationModel.isLoading = false
            if var detail = detailStore[activeID] {
                detail.streamingMessages[conversation.id] = nil
                detailStore[activeID] = detail
            }
        }

        guard let scope = currentWorkspaceScope() else {
            errorAuthority.publish(
                EngineError.contextLoadFailed("No selection"),
                context: "Codex Error"
            )
            return conversation
        }

        do {
            switch presentationModel.modelChoice {
            case .codex:
                let answer = try await codexService.askAboutWorkspaceNode(
                    scope: scope,
                    question: text
                ) { [weak self] streaming in
                    Task { @MainActor in
                        guard let self = self, let activeID = self.activeDetailID, var detail = self.detailStore[activeID] else { return }
                        detail.streamingMessages[conversation.id] = streaming
                        self.detailStore[activeID] = detail
                    }
                }
                var updated = conversation
                let assistant = AppCoreEngine.Message(role: .assistant, text: answer.text, createdAt: Date())
                updated.messages.append(assistant)
                codexContextByMessageID[assistant.id] = answer.context
                activeDetail.contextResult = answer.context
                // CodexAnswer.context is already UIContracts.UIContextBuildResult, but buildContextSnapshot needs domain type
                // We need to convert back temporarily - this is a design issue that should be fixed
                // For now, we'll skip building snapshot from UIContracts type
                // activeDetail.contextSnapshot = buildContextSnapshot(from: answer.context)
                detailStore[activeID] = activeDetail
                return updated
            case .stub:
                var updated = conversation
                let assistant = AppCoreEngine.Message(role: .assistant, text: "Stub: \(text)", createdAt: Date())
                updated.messages.append(assistant)
                return updated
            }
        } catch {
            errorAuthority.publish(error, context: "Codex Error")
            return conversation
        }
    }
    
    // MARK: - Context Building
    
    private func hasContextAnchor() -> Bool {
        !workspaceSnapshot.descriptorPaths.isEmpty
            || workspaceSnapshot.selectedPath != nil
            || workspaceSnapshot.contextPreferences.lastFocusedFilePath != nil
    }
    
    private func buildContextRequest(for conversation: AppCoreEngine.Conversation) -> AppCoreEngine.ConversationContextRequest {
        let selectedNode = activeDetailState.selectedDescriptorID.flatMap { descriptorID in
            presentationModel.rootFileNode?.findNode(withDescriptorID: AppCoreEngine.FileID(descriptorID.rawValue))
        }
        return ConversationContextRequest(
            snapshot: workspaceSnapshot,
            preferredDescriptorIDs: conversation.contextDescriptorIDs,
            fallbackContextURL: selectedNode?.path,
            budget: nil
        )
    }
    
    private func sendMessageWithContext(
        text: String,
        conversation: AppCoreEngine.Conversation,
        contextRequest: AppCoreEngine.ConversationContextRequest
    ) async throws -> (AppCoreEngine.Conversation, AppCoreEngine.ContextBuildResult) {
        try await withTimeout(seconds: 60) { [self] in
            try await conversationEngine.sendMessage(
                text,
                in: conversation,
                context: contextRequest,
                onStream: buildStreamHandler(for: conversation.id)
            )
        }
    }
    
    private func buildStreamHandler(for conversationID: UUID) -> ((AppCoreEngine.ConversationDelta) -> Void)? {
        { [weak self] event in
            guard let self = self, let activeID = self.activeDetailID else { return }
            Task { @MainActor in
                guard var detail = self.detailStore[activeID] else { return }
                switch event {
                case .context(let context):
                    detail.contextResult = DomainToUIMappers.toUIContextBuildResult(context)
                    detail.contextSnapshot = self.buildContextSnapshot(from: context)
                case .assistantStreaming(let aggregate):
                    detail.streamingMessages[conversationID] = aggregate
                case .assistantCommitted:
                    detail.streamingMessages[conversationID] = nil
                }
                self.detailStore[activeID] = detail
            }
        }
    }
    
    // MARK: - Decision Logic
    
    func currentWorkspaceScope() -> UIContracts.WorkspaceScope? {
        let correlationID = UUID()
        TeleologicalTracer.shared.trace("WorkspaceCoordinator.currentWorkspaceScope", power: .decisional, correlationID: correlationID)
        switch presentationModel.activeScope {
        case .selection:
            if let descriptorID = activeDetailState.selectedDescriptorID {
                return .descriptor(UIContracts.FileID(descriptorID.rawValue))
            }
            if let descriptorID = activeDetailState.selectedDescriptorID,
               let selectedNode = presentationModel.rootFileNode?.findNode(withDescriptorID: AppCoreEngine.FileID(descriptorID.rawValue)) {
                return .path(selectedNode.path.path)
            }
            return nil
        case .workspace:
            if let root = workspaceSnapshot.rootPath {
                return .path(root)
            }
            return nil
        case .selectionAndSiblings:
            if let descriptorID = activeDetailState.selectedDescriptorID {
                return .descriptor(UIContracts.FileID(descriptorID.rawValue))
            }
            return nil
        case .manual:
            if let descriptorID = activeDetailState.selectedDescriptorID {
                return .descriptor(UIContracts.FileID(descriptorID.rawValue))
            }
            return nil
        }
    }
    
    public func canAskCodex() -> Bool {
        currentWorkspaceScope() != nil
    }
    
    public func setContextScope(_ scope: UIContracts.ContextScopeChoice) {
        presentationModel.activeScope = scope
    }
    
    public func setModelChoice(_ model: UIContracts.ModelChoice) {
        presentationModel.modelChoice = model
    }
    
    public var streamingMessages: [UUID: String] {
        activeDetailState.streamingMessages
    }
    
    // MARK: - Context Snapshot Building
    
    func buildContextSnapshot(from result: AppCoreEngine.ContextBuildResult) -> UIContracts.ContextSnapshot {
        let encoder = WorkspaceContextEncoder()
        let encoded = encoder.encode(files: result.attachments)
        let encodedByPath = Dictionary(uniqueKeysWithValues: encoded.map { ($0.path, $0) })
        
        let segments = buildSegments(from: result.encodedSegments)
        let included = buildFileDescriptors(
            from: result.attachments,
            encodedByPath: encodedByPath,
            isIncluded: true,
            isTruncated: false
        )
        let truncated = buildFileDescriptors(
            from: result.truncatedFiles,
            encodedByPath: encodedByPath,
            isIncluded: true,
            isTruncated: true
        )
        let excluded = buildExcludedDescriptors(
            from: result.excludedFiles,
            encodedByPath: encodedByPath
        )
        
        return UIContracts.ContextSnapshot(
            scope: presentationModel.activeScope,
            snapshotHash: workspaceSnapshot.snapshotHash,
            segments: segments,
            includedFiles: included,
            truncatedFiles: truncated,
            excludedFiles: excluded,
            totalTokens: result.totalTokens,
            totalBytes: result.totalBytes
        )
    }
    
    private func buildSegments(
        from encodedSegments: [AppCoreEngine.ContextSegment]
    ) -> [UIContracts.ContextSegmentDescriptor] {
        encodedSegments.map { segment in
            UIContracts.ContextSegmentDescriptor(
                totalTokens: segment.totalTokens,
                totalBytes: segment.totalBytes,
                files: segment.files.map { file in
                    UIContracts.ContextFileDescriptor(
                        path: file.path,
                        language: file.language,
                        size: file.size,
                        hash: file.hash,
                        isIncluded: true,
                        isTruncated: false
                    )
                }
            )
        }
    }
    
    private func buildFileDescriptors(
        from files: [LoadedFile],
        encodedByPath: [String: AppCoreEngine.EncodedContextFile],
        isIncluded: Bool,
        isTruncated: Bool
    ) -> [UIContracts.ContextFileDescriptor] {
        files.sorted { $0.url.path < $1.url.path }.map { file in
            let path = file.url.path
            let encodedFile = encodedByPath[path]
            return UIContracts.ContextFileDescriptor(
                path: path,
                language: encodedFile?.language ?? file.fileTypeIdentifier,
                size: file.byteCount,
                hash: encodedFile?.hash ?? "",
                isIncluded: isIncluded,
                isTruncated: isTruncated
            )
        }
    }
    
    private func buildExcludedDescriptors(
        from excludedFiles: [AppCoreEngine.ContextExclusion],
        encodedByPath: [String: AppCoreEngine.EncodedContextFile]
    ) -> [UIContracts.ContextFileDescriptor] {
        excludedFiles.sorted { $0.file.url.path < $1.file.url.path }.map { exclusion in
            let file = exclusion.file
            let path = file.url.path
            let encodedFile = encodedByPath[path]
            return UIContracts.ContextFileDescriptor(
                path: path,
                language: encodedFile?.language ?? file.fileTypeIdentifier,
                size: file.byteCount,
                hash: encodedFile?.hash ?? "",
                isIncluded: false,
                isTruncated: false
            )
        }
    }
    
    // MARK: - Error Handling
    
    private func handleContextLoadFailure(message: String) {
        let error = EngineError.contextLoadFailed(message)
        errorAuthority.publish(error, context: "Context load failure")
        if let activeID = activeDetailID, var detail = detailStore[activeID] {
            detail.contextResult = nil
            detailStore[activeID] = detail
        }
    }
    
    private func handleSendMessageError(_ error: Error) {
        errorAuthority.publish(error, context: "Send message failure")
        if let activeID = activeDetailID, var detail = detailStore[activeID] {
            detail.contextResult = nil
            detailStore[activeID] = detail
        }
    }
    
    // MARK: - Utility
    
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
    
    private struct TimeoutError: LocalizedError {
        let seconds: Double
        var errorDescription: String? { "Operation timed out after \(seconds) seconds." }
    }
    
    // MARK: - Conversation Helpers
    
    func conversation(for url: URL) async -> AppCoreEngine.Conversation {
        if let engineConvo = await conversationEngine.conversation(for: url) {
            return engineConvo
        }
        return AppCoreEngine.Conversation(contextFilePaths: [url.path])
    }
    
    func conversation(forDescriptorID descriptorID: AppCoreEngine.FileID) async -> AppCoreEngine.Conversation? {
        if let engineConvo = await conversationEngine.conversation(forDescriptorIDs: [descriptorID]) {
            return engineConvo
        }
        if let url = url(for: descriptorID) {
            return await conversation(for: url)
        }
        return nil
    }
    
    func ensureConversation(for url: URL) async {
        do {
            _ = try await conversationEngine.ensureConversation(for: url)
        } catch {
            errorAuthority.publish(error, context: "Ensure conversation")
        }
    }
    
    func ensureConversation(forDescriptorID descriptorID: AppCoreEngine.FileID) async {
        do {
            _ = try await conversationEngine.ensureConversation(forDescriptorIDs: [descriptorID]) { [weak self] id in
                self?.descriptorPaths[id]
            }
        } catch {
            errorAuthority.publish(error, context: "Ensure conversation via descriptor")
        }
    }
    
    func contextForMessage(_ id: UUID) -> UIContracts.UIContextBuildResult? {
        codexContextByMessageID[id]
    }
    
    // MARK: - Helpers
    
    private var descriptorPaths: [AppCoreEngine.FileID: String] {
        workspaceSnapshot.descriptorPaths
    }
    
    func url(for descriptorID: AppCoreEngine.FileID) -> URL? {
        descriptorPaths[descriptorID].map { URL(fileURLWithPath: $0) }
    }
    
    // MARK: - Workspace Operations
    
    /// Open workspace at the given URL (public API for composition)
    public func openWorkspace(at url: URL) async {
        presentationModel.isLoading = true
        defer { presentationModel.isLoading = false }
        do {
            let snapshot = try await withTimeout(seconds: 30) { [self] in
                try await workspaceEngine.openWorkspace(rootPath: url.path)
            }
            workspaceSnapshot = snapshot
            _ = await workspaceEngine.treeProjection()
            // Update will be handled by WorkspaceStateObserver
            loadProjectTodos(for: url)
        } catch let timeout as TimeoutError {
            errorAuthority.publish(timeout, context: "Load Timed Out")
        } catch {
            errorAuthority.publish(error, context: "Failed to Load Project")
        }
    }
    
    func selectPath(_ url: URL?) async {
        do {
            let snapshot = try await withTimeout(seconds: 10) { [self] in
                try await workspaceEngine.select(path: url?.path)
            }
            workspaceSnapshot = snapshot
            // Update will be handled by WorkspaceStateObserver
        } catch let timeout as TimeoutError {
            errorAuthority.publish(timeout, context: "Selection Timed Out")
        } catch {
            errorAuthority.publish(error, context: "Failed to Select File")
        }
    }
    
    func loadProjectTodos(for root: URL?) {
        guard let root else {
            presentationModel.projectTodos = .empty
            presentationModel.todosError = nil
            return
        }
        Task {
            do {
                let todos = try projectTodosLoader.loadTodos(for: root)
                await MainActor.run {
                    let uiTodos = DomainToUIMappers.toUIProjectTodos(todos)
                    presentationModel.projectTodos = UIContracts.ProjectTodos(
                        generatedAt: uiTodos.generatedAt,
                        missingHeaders: uiTodos.missingHeaders,
                        missingFolderTelos: uiTodos.missingFolderTelos,
                        filesWithIncompleteHeaders: uiTodos.filesWithIncompleteHeaders,
                        foldersWithIncompleteTelos: uiTodos.foldersWithIncompleteTelos,
                        allTodos: uiTodos.allTodos
                    )
                    presentationModel.todosError = nil
                }
            } catch {
                await MainActor.run {
                    presentationModel.projectTodos = .empty
                    presentationModel.todosError = "Failed to load ProjectTodos.ent.json: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func setContextInclusion(_ include: Bool, for url: URL) {
        guard workspaceSnapshot.rootPath != nil else { return }
        Task {
            do {
                let snapshot = try await workspaceEngine.setContextInclusion(path: url.path, included: include)
                workspaceSnapshot = snapshot
                _ = await workspaceEngine.treeProjection()
                // Update will be handled by WorkspaceStateObserver
            } catch {
                errorAuthority.publish(error, context: "Set Context Inclusion")
            }
        }
    }
    
    /// Check if path is included in context (public API for composition)
    public func isPathIncludedInContext(_ url: URL) -> Bool {
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
    
    func toggleExpanded(descriptorID: AppCoreEngine.FileID) {
        let uiFileID = UIContracts.FileID(descriptorID.rawValue)
        if presentationModel.expandedDescriptorIDs.contains(uiFileID) {
            presentationModel.expandedDescriptorIDs.remove(uiFileID)
        } else {
            presentationModel.expandedDescriptorIDs.insert(uiFileID)
        }
    }
    
    func isExpanded(descriptorID: AppCoreEngine.FileID) -> Bool {
        let uiFileID = UIContracts.FileID(descriptorID.rawValue)
        return presentationModel.expandedDescriptorIDs.contains(uiFileID)
    }
    
    func publishFileBrowserError(_ error: Error) {
        errorAuthority.publish(error, context: "Failed to Read Folder")
    }
    
    // MARK: - Workspace Snapshot Access
    
    func updateWorkspaceSnapshot(_ snapshot: WorkspaceSnapshot) {
        workspaceSnapshot = snapshot
    }
    
    func getWorkspaceSnapshot() -> WorkspaceSnapshot {
        workspaceSnapshot
    }
    
    // MARK: - ViewState Derivation (Public API for Composition)
    
    /// Derive WorkspaceUIViewState from internal state
    public func deriveWorkspaceUIViewState() -> UIContracts.WorkspaceUIViewState {
        let rootDirectory = projection.workspaceState.rootPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
        let selectedNode = detailState.selectedDescriptorID.flatMap { descriptorID in
            presentationModel.rootFileNode?.findNode(withDescriptorID: AppCoreEngine.FileID(descriptorID.rawValue))
        }
        return UIContracts.WorkspaceUIViewState(
            selectedNode: selectedNode?.toUIContracts(),
            selectedDescriptorID: detailState.selectedDescriptorID,
            rootFileNode: presentationModel.rootFileNode?.toUIContracts(),
            rootDirectory: rootDirectory,
            projectTodos: presentationModel.projectTodos,
            todosErrorDescription: presentationModel.todosError
        )
    }
    
    /// Derive ContextViewState from internal state
    public func deriveContextViewState(bannerMessage: String?) -> UIContracts.ContextViewState {
        UIContracts.ContextViewState(
            lastContextSnapshot: detailState.contextSnapshot,
            lastContextResult: detailState.contextResult,
            streamingMessages: detailState.streamingMessages,
            bannerMessage: bannerMessage,
            contextByMessageID: codexContextByMessageID
        )
    }
    
    /// Activate detail state for selection (create if needed, preserve if exists).
    /// Selection change switches active DetailState, does not destroy it.
    func replaceDetailState(for selection: UIContracts.FileID?) {
        if let selectionID = selection {
            // Activate existing or create new DetailState for this identity
            if detailStore[selectionID] == nil {
                detailStore[selectionID] = DetailState(selectedDescriptorID: selectionID)
            }
            activeDetailID = selectionID
        } else {
            // Deselect: clear active ID, but preserve stored DetailStates
            activeDetailID = nil
        }
    }
    
    /// Clear all detail states (called on project close).
    func clearDetailStore() {
        detailStore.removeAll()
        activeDetailID = nil
    }
    
    /// Get current inspector tab
    public func inspectorTab() -> UIContracts.InspectorTab {
        detailState.inspectorTab
    }
    
    /// Set inspector tab
    public func setInspectorTab(_ tab: UIContracts.InspectorTab) {
        detailState.inspectorTab = tab
    }
    
    /// Derive PresentationViewState from internal state
    public func derivePresentationViewState() -> UIContracts.PresentationViewState {
        UIContracts.PresentationViewState(
            activeNavigator: presentationModel.activeNavigator,
            filterText: presentationModel.filterText,
            expandedDescriptorIDs: presentationModel.expandedDescriptorIDs
        )
    }
    
    /// Handle workspace intent
    public func handle(_ intent: UIContracts.WorkspaceIntent) {
        switch intent {
        case .selectNode(let node):
            if let descriptorID = node?.descriptorID {
                Task {
                    await selectPath(URL(fileURLWithPath: descriptorID.rawValue.uuidString))
                }
            } else {
                Task {
                    await selectPath(nil)
                }
            }
        case .selectDescriptorID(let descriptorID):
            let engineFileID = AppCoreEngine.FileID(descriptorID.rawValue)
            Task {
                await selectPath(url(for: engineFileID))
            }
        case .setContextInclusion(let include, let url):
            // Context inclusion is handled by workspace engine
            Task {
                do {
                    _ = try await workspaceEngine.setContextInclusion(path: url.path, included: include)
                } catch {
                    errorAuthority.publish(error, context: "Set Context Inclusion")
                }
            }
        case .loadFilePreview(_):
            // File preview loading - not implemented in coordinator
            break
        case .loadFileStats(_):
            // File stats loading - not implemented in coordinator
            break
        case .loadFolderStats(_):
            // Folder stats loading - not implemented in coordinator
            break
        case .clearFilePreview:
            // File preview clearing - not implemented in coordinator
            break
        case .clearFileStats:
            // File stats clearing - not implemented in coordinator
            break
        case .clearFolderStats:
            // Folder stats clearing - not implemented in coordinator
            break
        case .clearBanner:
            // Banner clearing - handled by composition layer
            break
        case .toggleExpanded(let descriptorID):
            toggleExpanded(descriptorID: AppCoreEngine.FileID(descriptorID.rawValue))
        case .setActiveNavigator(let mode):
            presentationModel.activeNavigator = mode
        case .setFilterText(let text):
            presentationModel.filterText = text
        case .clearExpanded:
            presentationModel.expandedDescriptorIDs.removeAll()
        }
    }
    
}

