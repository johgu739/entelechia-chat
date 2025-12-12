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
        // Subscribe to streaming publisher if available
        if let workspaceVM = workspace as? WorkspaceViewModel {
            streamingObservation = workspaceVM.streamingPublisher
                .sink { [weak self] conversationID, streamingText in
                    guard let self = self,
                          let viewModel = self.chatViewModel,
                          conversationID == self.currentStreamingConversationID else { return }
                    
                    if let text = streamingText, !text.isEmpty {
                        viewModel.applyDelta(.assistantStreaming(text))
                    } else {
                        // Streaming finished
                        if viewModel.streamingText != nil {
                            viewModel.finishStreaming()
                        }
                    }
                }
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
        
        // Streaming updates now flow automatically via Combine subscription in setupStreamingObservation()
        // Set up a timeout to handle cases where no response is received
        if !isCodexAvailable {
            // For non-Codex mode, provide fallback after a delay
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    if chatViewModel?.streamingText == nil && chatViewModel?.messages.last?.role != .assistant {
                        provideFallbackResponseSync(for: conversationID)
                    }
                }
            }
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

