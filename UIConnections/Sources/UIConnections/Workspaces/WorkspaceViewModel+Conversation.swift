import Foundation
import AppCoreEngine

public extension WorkspaceViewModel {
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
    
    @MainActor
    func ensureConversation(forDescriptorID descriptorID: FileID) async {
        do {
            _ = try await conversationEngine.ensureConversation(forDescriptorIDs: [descriptorID]) { [weak self] id in
                self?.descriptorPaths[id]
            }
        } catch {
            let wrapped = WorkspaceViewModelError.conversationEnsureFailed(error)
            logger.error(
                "Failed to ensure conversation via descriptor: " +
                "\(error.localizedDescription, privacy: .public)"
            )
            alertCenter?.publish(wrapped, fallbackTitle: "Conversation Error")
        }
    }
    
    // FROZEN: Orchestration methods will be moved to WorkspaceCoordinator in form recovery Step 3.
    // Do not add new orchestration logic here.
    func sendMessage(_ text: String, for conversation: Conversation) async {
        isLoading = true
        streamingMessages[conversation.id] = ""
        defer {
            isLoading = false
            streamingMessages[conversation.id] = nil
        }
        
        do {
            guard hasContextAnchor() else {
                handleContextLoadFailure(message: "Context load failed: no selection")
                return
            }

            var convo = conversation
            if let did = selectedDescriptorID {
                convo.contextDescriptorIDs = [did]
            }
            let contextRequest = buildContextRequest(for: convo)
            let (_, contextResult) = try await sendMessageWithContext(
                text: text,
                conversation: convo,
                contextRequest: contextRequest
            )
            lastContextResult = contextResult
            lastContextSnapshot = buildContextSnapshot(from: contextResult)
            
        } catch {
            handleSendMessageError(error)
        }
    }
    
    private func hasContextAnchor() -> Bool {
        !workspaceSnapshot.descriptorPaths.isEmpty
            || workspaceSnapshot.selectedPath != nil
            || workspaceSnapshot.contextPreferences.lastFocusedFilePath != nil
    }
    
    private func handleContextLoadFailure(message: String) {
        alertCenter?.publish(
            WorkspaceViewModelError.conversationEnsureFailed(
                EngineError.contextLoadFailed(message)
            ),
            fallbackTitle: "Context Error"
        )
        contextErrorSubject.send(EngineError.contextLoadFailed(message))
        lastContextResult = nil
    }
    
    private func buildContextRequest(for conversation: Conversation) -> ConversationContextRequest {
        ConversationContextRequest(
            snapshot: workspaceSnapshot,
            preferredDescriptorIDs: conversation.contextDescriptorIDs,
            fallbackContextURL: selectedNode?.path,
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
                    self.lastContextResult = context
                    self.lastContextSnapshot = self.buildContextSnapshot(from: context)
                case .assistantStreaming(let aggregate):
                    self.streamingMessages[conversationID] = aggregate
                case .assistantCommitted:
                    self.streamingMessages[conversationID] = nil
                }
            }
        }
    }
    
    private func handleSendMessageError(_ error: Error) {
        let wrapped = WorkspaceViewModelError.conversationEnsureFailed(error)
        logger.error("Failed to send message: \(error.localizedDescription, privacy: .public)")
        if case EngineError.contextLoadFailed(let message) = error {
            alertCenter?.publish(
                WorkspaceViewModelError.conversationEnsureFailed(error),
                fallbackTitle: "Context Load Failed: \(message)"
            )
            contextErrorSubject.send(EngineError.contextLoadFailed(message))
        } else {
            alertCenter?.publish(wrapped, fallbackTitle: "Conversation Error")
        }
        lastContextResult = nil
    }

    // FROZEN: Orchestration methods will be moved to WorkspaceCoordinator in form recovery Step 3.
    // Do not add new orchestration logic here.
    func askCodex(_ text: String, for conversation: Conversation) async -> Conversation {
        isLoading = true
        streamingMessages[conversation.id] = ""
        defer {
            isLoading = false
            streamingMessages[conversation.id] = nil
        }

        guard let scope = currentWorkspaceScope() else {
            alertCenter?.publish(
                WorkspaceViewModelError.conversationEnsureFailed(
                    EngineError.contextLoadFailed("No selection")
                ),
                fallbackTitle: "Codex Error"
            )
            return conversation
        }

        do {
            switch modelChoice {
            case .codex:
                let answer = try await codexService.askAboutWorkspaceNode(
                    scope: scope,
                    question: text
                ) { [weak self] streaming in
                    Task { @MainActor in
                        self?.streamingMessages[conversation.id] = streaming
                    }
                }
                var updated = conversation
                let assistant = Message(role: .assistant, text: answer.text, createdAt: Date())
                updated.messages.append(assistant)
                codexContextByMessageID[assistant.id] = answer.context
                lastContextResult = answer.context
                lastContextSnapshot = buildContextSnapshot(from: answer.context)
                return updated
            case .stub:
                var updated = conversation
                let assistant = Message(role: .assistant, text: "Stub: \(text)", createdAt: Date())
                updated.messages.append(assistant)
                return updated
            }
        } catch {
            alertCenter?.publish(WorkspaceViewModelError.conversationEnsureFailed(error), fallbackTitle: "Codex Error")
            return conversation
        }
    }

    func contextForMessage(_ id: UUID) -> ContextBuildResult? {
        codexContextByMessageID[id]
    }
}

