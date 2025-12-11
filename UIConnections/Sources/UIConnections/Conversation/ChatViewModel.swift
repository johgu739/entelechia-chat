import Foundation
import Combine
import AppCoreEngine

/// Presentation-layer model for chat controls (model + scope selectors + intents).
@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public var text: String = ""
    @Published public var model: ModelChoice
    @Published public var contextScope: ContextScopeChoice
    @Published public var isSending: Bool = false
    @Published public var isAsking: Bool = false
    
    // Core message state for optimistic rendering
    @Published public var messages: [Message] = []
    @Published public var streamingText: String?
    
    private let coordinator: ConversationCoordinator
    private let contextSelection: ContextSelectionState
    private var cancellables: Set<AnyCancellable> = []
    private var currentConversationID: UUID?
    
    public init(
        coordinator: ConversationCoordinator,
        contextSelection: ContextSelectionState
    ) {
        self.coordinator = coordinator
        self.contextSelection = contextSelection
        self.model = contextSelection.modelChoice
        self.contextScope = contextSelection.scopeChoice
        bindSelection()
    }
    
    public func selectModel(_ choice: ModelChoice) {
        if model != choice { model = choice }
        coordinator.setModelChoice(choice)
    }
    
    public func setModelChoice(_ choice: ModelChoice) {
        selectModel(choice)
    }
    
    public func selectScope(_ choice: ContextScopeChoice) {
        if contextScope != choice { contextScope = choice }
        coordinator.setScopeChoice(choice)
    }
    
    public func setScopeChoice(_ choice: ContextScopeChoice) {
        selectScope(choice)
    }
    
    public func clearText() {
        text = ""
    }
    
    /// Load conversation messages into view model for display
    public func loadConversation(_ conversation: Conversation) {
        currentConversationID = conversation.id
        messages = conversation.messages
        streamingText = nil
    }
    
    /// Commit user message synchronously (optimistic render)
    /// Returns the user message that was appended
    @discardableResult
    public func commitMessage() -> Message? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let userMessage = Message(role: .user, text: trimmed, createdAt: Date())
        messages.append(userMessage)
        text = ""
        isSending = true
        
        return userMessage
    }
    
    /// Apply streaming delta update
    public func applyDelta(_ delta: ConversationDelta) {
        switch delta {
        case .context:
            // Context updates are handled by workspace view model
            break
        case .assistantStreaming(let aggregate):
            streamingText = aggregate
        case .assistantCommitted(let message):
            streamingText = nil
            messages.append(message)
            isSending = false
        }
    }
    
    /// Finish streaming and finalize assistant message
    public func finishStreaming() {
        if let finalText = streamingText, !finalText.isEmpty {
            let assistantMessage = Message(role: .assistant, text: finalText, createdAt: Date())
            messages.append(assistantMessage)
        }
        streamingText = nil
        isSending = false
    }
    
    /// Legacy send method for backward compatibility
    public func send(conversation: Conversation, onComplete: @escaping () -> Void) {
        guard let userMessage = commitMessage() else {
            onComplete()
            return
        }
        
        Task {
            await coordinator.sendMessage(userMessage.text, in: conversation)
            await MainActor.run {
                onComplete()
            }
        }
    }
    
    public func askCodex(conversation: Conversation, onResult: @escaping (Conversation) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard coordinator.canAskCodex() else { return }
        isAsking = true
        Task {
            let updated = await coordinator.askCodex(trimmed, in: conversation)
            await MainActor.run {
                self.isAsking = false
                self.text = ""
                onResult(updated)
            }
        }
    }
    
    private func bindSelection() {
        contextSelection.$modelChoice
            .sink { [weak self] choice in
                guard let self else { return }
                if self.model != choice {
                    self.model = choice
                }
            }
            .store(in: &cancellables)
        
        contextSelection.$scopeChoice
            .sink { [weak self] choice in
                guard let self else { return }
                if self.contextScope != choice {
                    self.contextScope = choice
                }
            }
            .store(in: &cancellables)
    }
}

