import Foundation
import AppCoreEngine
import Combine

/// Minimal workspace surface required for coordinating chat intents.
@MainActor
public protocol ConversationWorkspaceHandling: AnyObject {
    func sendMessage(_ text: String, for conversation: Conversation) async
    func askCodex(_ text: String, for conversation: Conversation) async -> Conversation
    func setContextScope(_ scope: ContextScopeChoice)
    func setModelChoice(_ model: ModelChoice)
    func canAskCodex() -> Bool
    var streamingMessages: [UUID: String] { get }
}

@MainActor
public final class ConversationCoordinator: ObservableObject {
    private let workspace: ConversationWorkspaceHandling
    private let contextSelection: ContextSelectionState
    private let codexStatusModel: CodexStatusModel
    private weak var chatViewModel: ChatViewModel?
    private var streamingObservation: AnyCancellable?
    private var currentStreamingConversationID: UUID?
    
    public init(
        workspace: ConversationWorkspaceHandling,
        contextSelection: ContextSelectionState,
        codexStatusModel: CodexStatusModel
    ) {
        self.workspace = workspace
        self.contextSelection = contextSelection
        self.codexStatusModel = codexStatusModel
        setupStreamingObservation()
    }
    
    /// Set the ChatViewModel to receive streaming updates
    public func setChatViewModel(_ viewModel: ChatViewModel) {
        self.chatViewModel = viewModel
    }
    
    private func setupStreamingObservation() {
        // Observe workspace streamingMessages if it's ObservableObject
        if let observableWorkspace = workspace as? any ObservableObject {
            // Use Combine to observe streaming updates
            // Note: This requires WorkspaceViewModel to be ObservableObject (which it is)
        }
    }
    
    /// Stream a message and forward deltas to ChatViewModel
    public func stream(_ text: String, in conversation: Conversation) async {
        guard let viewModel = chatViewModel else {
            // Fallback to legacy path if no view model
            await workspace.sendMessage(text, for: conversation)
            return
        }
        
        let conversationID = conversation.id
        currentStreamingConversationID = conversationID
        
        // Check Codex availability
        let isCodexAvailable: Bool
        switch codexStatusModel.state {
        case .connected:
            isCodexAvailable = true
        case .degradedStub, .misconfigured:
            isCodexAvailable = false
        }
        
        // Start streaming through workspace
        await workspace.sendMessage(text, for: conversation)
        
        // Monitor for streaming updates and forward to ChatViewModel
        // We'll poll workspace.streamingMessages and forward deltas
        await monitorAndForwardStreaming(
            conversationID: conversationID,
            isCodexAvailable: isCodexAvailable
        )
    }
    
    private func monitorAndForwardStreaming(
        conversationID: UUID,
        isCodexAvailable: Bool
    ) async {
        var lastStreamingText: String? = nil
        var hasReceivedResponse = false
        let maxWaitTime: UInt64 = 5_000_000_000 // 5 seconds
        let pollInterval: UInt64 = 50_000_000 // 50ms
        var elapsed: UInt64 = 0
        
        while elapsed < maxWaitTime {
            await MainActor.run {
                guard let viewModel = chatViewModel else { return }
                
                // Check for streaming updates
                if let workspace = workspace as? WorkspaceViewModel {
                    let currentStreaming = workspace.streamingMessages[conversationID]
                    
                    if let streaming = currentStreaming, !streaming.isEmpty {
                        hasReceivedResponse = true
                        if streaming != lastStreamingText {
                            viewModel.applyDelta(.assistantStreaming(streaming))
                            lastStreamingText = streaming
                        }
                    } else if lastStreamingText != nil && currentStreaming == nil {
                        // Streaming finished - check if we need to finalize
                        if viewModel.streamingText != nil {
                            viewModel.finishStreaming()
                        }
                        return
                    }
                }
            }
            
            // If no response and Codex unavailable, provide fallback
            if !hasReceivedResponse && !isCodexAvailable && elapsed > 500_000_000 {
                // Wait 0.5s before providing fallback
                await provideFallbackResponse(for: conversationID)
                return
            }
            
            try? await Task.sleep(nanoseconds: pollInterval)
            elapsed += pollInterval
        }
        
        // Finalize if still streaming
        await MainActor.run {
            guard let viewModel = chatViewModel else { return }
            if viewModel.streamingText != nil {
                viewModel.finishStreaming()
            } else if !hasReceivedResponse && !isCodexAvailable {
                // Provide fallback if we never got a response
                provideFallbackResponseSync(for: conversationID)
            }
        }
    }
    
    private func provideFallbackResponse(for conversationID: UUID) async {
        await MainActor.run {
            provideFallbackResponseSync(for: conversationID)
        }
    }
    
    private func provideFallbackResponseSync(for conversationID: UUID) {
        guard let viewModel = chatViewModel else { return }
        
        // Only provide fallback if we haven't received a response
        if viewModel.streamingText == nil && viewModel.messages.last?.role != .assistant {
            let fallbackMessage = Message(
                role: .assistant,
                text: "Codex is currently unavailable.",
                createdAt: Date()
            )
            viewModel.applyDelta(.assistantCommitted(fallbackMessage))
        }
    }
    
    public func sendMessage(_ text: String, in conversation: Conversation) async {
        await stream(text, in: conversation)
    }
    
    public func askCodex(_ text: String, in conversation: Conversation) async -> Conversation {
        await workspace.askCodex(text, for: conversation)
    }
    
    public func setScopeChoice(_ choice: ContextScopeChoice) {
        contextSelection.setScopeChoice(choice)
        workspace.setContextScope(choice)
    }
    
    public func setModelChoice(_ choice: ModelChoice) {
        contextSelection.setModelChoice(choice)
        workspace.setModelChoice(choice)
    }
    
    public func scopeChoice() -> ContextScopeChoice {
        contextSelection.scopeChoice
    }
    
    public func modelChoice() -> ModelChoice {
        contextSelection.modelChoice
    }
    
    public func canAskCodex() -> Bool {
        workspace.canAskCodex()
    }
}

