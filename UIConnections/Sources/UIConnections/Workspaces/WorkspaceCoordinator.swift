import Foundation
import Combine
import os.log
import AppCoreEngine

/// Coordinator for workspace orchestration.
/// Power: Decisional (orchestrates workflows, makes decisions, coordinates engines)
/// Owns async logic, context building, error handling, and decision-making.
@MainActor
public final class WorkspaceCoordinator: ConversationWorkspaceHandling {
    // MARK: - Dependencies
    
    private let workspaceEngine: WorkspaceEngine
    private let conversationEngine: ConversationStreaming
    private let codexService: CodexQuerying
    private let projectTodosLoader: ProjectTodosLoading
    private let presentationModel: WorkspacePresentationModel
    private let projection: WorkspaceProjection
    private let errorAuthority: DomainErrorAuthority
    private let logger = Logger(subsystem: "UIConnections", category: "WorkspaceCoordinator")
    
    // MARK: - Private State
    
    private var workspaceSnapshot: WorkspaceSnapshot = .empty
    private var codexContextByMessageID: [UUID: ContextBuildResult] = [:]
    
    // MARK: - Initialization
    
    public init(
        workspaceEngine: WorkspaceEngine,
        conversationEngine: ConversationStreaming,
        codexService: CodexQuerying,
        projectTodosLoader: ProjectTodosLoading,
        presentationModel: WorkspacePresentationModel,
        projection: WorkspaceProjection,
        errorAuthority: DomainErrorAuthority
    ) {
        self.workspaceEngine = workspaceEngine
        self.conversationEngine = conversationEngine
        self.codexService = codexService
        self.projectTodosLoader = projectTodosLoader
        self.presentationModel = presentationModel
        self.projection = projection
        self.errorAuthority = errorAuthority
    }
    
    // MARK: - ConversationWorkspaceHandling Protocol
    
    public func sendMessage(_ text: String, for conversation: Conversation) async {
        presentationModel.isLoading = true
        projection.streamingMessages[conversation.id] = ""
        defer {
            presentationModel.isLoading = false
            projection.streamingMessages[conversation.id] = nil
        }
        
        do {
            guard hasContextAnchor() else {
                handleContextLoadFailure(message: "Context load failed: no selection")
                return
            }

            var convo = conversation
            if let did = presentationModel.selectedDescriptorID {
                convo.contextDescriptorIDs = [did]
            }
            let contextRequest = buildContextRequest(for: convo)
            let (_, contextResult) = try await sendMessageWithContext(
                text: text,
                conversation: convo,
                contextRequest: contextRequest
            )
            projection.lastContextResult = contextResult
            projection.lastContextSnapshot = buildContextSnapshot(from: contextResult)
            
        } catch {
            handleSendMessageError(error)
        }
    }
    
    public func askCodex(_ text: String, for conversation: Conversation) async -> Conversation {
        presentationModel.isLoading = true
        projection.streamingMessages[conversation.id] = ""
        defer {
            presentationModel.isLoading = false
            projection.streamingMessages[conversation.id] = nil
        }

        guard let scope = currentWorkspaceScope() else {
            // Error will be handled by error authority
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
                        self?.projection.streamingMessages[conversation.id] = streaming
                    }
                }
                var updated = conversation
                let assistant = Message(role: .assistant, text: answer.text, createdAt: Date())
                updated.messages.append(assistant)
                codexContextByMessageID[assistant.id] = answer.context
                projection.lastContextResult = answer.context
                projection.lastContextSnapshot = buildContextSnapshot(from: answer.context)
                return updated
            case .stub:
                var updated = conversation
                let assistant = Message(role: .assistant, text: "Stub: \(text)", createdAt: Date())
                updated.messages.append(assistant)
                return updated
            }
        } catch {
            // Error will be handled by error authority
            return conversation
        }
    }
    
    // MARK: - Context Building
    
    private func hasContextAnchor() -> Bool {
        !workspaceSnapshot.descriptorPaths.isEmpty
            || workspaceSnapshot.selectedPath != nil
            || workspaceSnapshot.contextPreferences.lastFocusedFilePath != nil
    }
    
    private func buildContextRequest(for conversation: Conversation) -> ConversationContextRequest {
        ConversationContextRequest(
            snapshot: workspaceSnapshot,
            preferredDescriptorIDs: conversation.contextDescriptorIDs,
            fallbackContextURL: presentationModel.selectedNode?.path,
            budget: nil
        )
    }
    
    private func sendMessageWithContext(
        text: String,
        conversation: Conversation,
        contextRequest: ConversationContextRequest
    ) async throws -> (Conversation, ContextBuildResult) {
        try await withTimeout(seconds: 60) { [self] in
            try await conversationEngine.sendMessage(
                text,
                in: conversation,
                context: contextRequest,
                onStream: buildStreamHandler(for: conversation.id)
            )
        }
    }
    
    private func buildStreamHandler(for conversationID: UUID) -> ((ConversationDelta) -> Void)? {
        { [weak self] event in
            guard let self = self else { return }
            Task { @MainActor in
                switch event {
                case .context(let context):
                    self.projection.lastContextResult = context
                    self.projection.lastContextSnapshot = self.buildContextSnapshot(from: context)
                case .assistantStreaming(let aggregate):
                    self.projection.streamingMessages[conversationID] = aggregate
                case .assistantCommitted:
                    self.projection.streamingMessages[conversationID] = nil
                }
            }
        }
    }
    
    // MARK: - Decision Logic
    
    func currentWorkspaceScope() -> WorkspaceScope? {
        switch presentationModel.activeScope {
        case .selection:
            if let descriptorID = presentationModel.selectedDescriptorID {
                return .descriptor(descriptorID)
            }
            if let path = presentationModel.selectedNode?.path.path {
                return .path(path)
            }
            return nil
        case .workspace:
            if let root = workspaceSnapshot.rootPath {
                return .path(root)
            }
            return nil
        case .selectionAndSiblings:
            if let descriptorID = presentationModel.selectedDescriptorID {
                return .descriptor(descriptorID)
            }
            return nil
        case .manual:
            if let descriptorID = presentationModel.selectedDescriptorID {
                return .descriptor(descriptorID)
            }
            return nil
        }
    }
    
    public func canAskCodex() -> Bool {
        currentWorkspaceScope() != nil
    }
    
    public func setContextScope(_ scope: ContextScopeChoice) {
        presentationModel.activeScope = scope
    }
    
    public func setModelChoice(_ model: ModelChoice) {
        presentationModel.modelChoice = model
    }
    
    public var streamingMessages: [UUID: String] {
        projection.streamingMessages
    }
    
    // MARK: - Context Snapshot Building
    
    func buildContextSnapshot(from result: ContextBuildResult) -> ContextSnapshot {
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
        
        return ContextSnapshot(
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
        from encodedSegments: [ContextBuildResult.EncodedSegment]
    ) -> [ContextSegmentDescriptor] {
        encodedSegments.map { segment in
            let files = segment.files.map { file in
                ContextFileDescriptor(
                    path: file.path,
                    language: file.language,
                    size: file.size,
                    hash: file.hash,
                    isIncluded: true,
                    isTruncated: false
                )
            }
            return ContextSegmentDescriptor(
                totalTokens: segment.totalTokens,
                totalBytes: segment.totalBytes,
                files: files
            )
        }
    }
    
    private func buildFileDescriptors(
        from files: [LoadedFile],
        encodedByPath: [String: WorkspaceContextEncoder.EncodedFile],
        isIncluded: Bool,
        isTruncated: Bool
    ) -> [ContextFileDescriptor] {
        files.sorted { $0.url.path < $1.url.path }.map { file in
            let path = file.url.path
            let encodedFile = encodedByPath[path]
            return ContextFileDescriptor(
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
        from excludedFiles: [ContextExclusion],
        encodedByPath: [String: WorkspaceContextEncoder.EncodedFile]
    ) -> [ContextFileDescriptor] {
        excludedFiles.sorted { $0.file.url.path < $1.file.url.path }.map { exclusion in
            let file = exclusion.file
            let path = file.url.path
            let encodedFile = encodedByPath[path]
            return ContextFileDescriptor(
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
        projection.lastContextResult = nil
    }
    
    private func handleSendMessageError(_ error: Error) {
        errorAuthority.publish(error, context: "Send message failure")
        projection.lastContextResult = nil
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
    
    func conversation(for url: URL) async -> Conversation {
        if let engineConvo = await conversationEngine.conversation(for: url) {
            return engineConvo
        }
        return Conversation(contextFilePaths: [url.path])
    }
    
    func conversation(forDescriptorID descriptorID: FileID) async -> Conversation? {
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
    
    func ensureConversation(forDescriptorID descriptorID: FileID) async {
        do {
            _ = try await conversationEngine.ensureConversation(forDescriptorIDs: [descriptorID]) { [weak self] id in
                self?.descriptorPaths[id]
            }
        } catch {
            errorAuthority.publish(error, context: "Ensure conversation via descriptor")
        }
    }
    
    func contextForMessage(_ id: UUID) -> ContextBuildResult? {
        codexContextByMessageID[id]
    }
    
    // MARK: - Helpers
    
    private var descriptorPaths: [FileID: String] {
        presentationModel.workspaceState.projection?.flattenedPaths ?? [:]
    }
    
    private func url(for descriptorID: FileID) -> URL? {
        descriptorPaths[descriptorID].map { URL(fileURLWithPath: $0) }
    }
    
    // MARK: - Workspace Snapshot Access
    
    func updateWorkspaceSnapshot(_ snapshot: WorkspaceSnapshot) {
        workspaceSnapshot = snapshot
    }
    
    func getWorkspaceSnapshot() -> WorkspaceSnapshot {
        workspaceSnapshot
    }
}

