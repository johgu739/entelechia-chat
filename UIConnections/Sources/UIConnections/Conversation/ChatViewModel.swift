import Foundation
import Combine
import AppCoreEngine
import UIContracts

/// Presentation-layer model for chat controls (model + scope selectors + intents).
@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public var text: String = ""
    @Published public var model: UIContracts.ModelChoice
    @Published public var contextScope: UIContracts.ContextScopeChoice
    @Published public var isSending: Bool = false
    @Published public var isAsking: Bool = false
    
    // Core message state for optimistic rendering
    @Published public var messages: [UIContracts.UIMessage] = []
    @Published public var streamingText: String?
    
    private let coordinator: ConversationCoordinator
    private let contextSelection: ContextSelectionState
    private var cancellables: Set<AnyCancellable> = []
    private var currentConversationID: UUID?
    
    // Internal domain types for coordination
    private var internalMessages: [AppCoreEngine.Message] = []
    
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
    
    public func selectModel(_ choice: UIContracts.ModelChoice) {
        if model != choice { model = choice }
        coordinator.setModelChoice(choice)
    }
    
    public func setModelChoice(_ choice: UIContracts.ModelChoice) {
        selectModel(choice)
    }
    
    public func selectScope(_ choice: UIContracts.ContextScopeChoice) {
        if contextScope != choice { contextScope = choice }
        coordinator.setScopeChoice(choice)
    }
    
    public func setScopeChoice(_ choice: UIContracts.ContextScopeChoice) {
        selectScope(choice)
    }
    
    public func clearText() {
        text = ""
    }
    
    /// Load conversation messages into view model for display
    public func loadConversation(_ conversation: UIContracts.UIConversation) {
        currentConversationID = conversation.id
        messages = conversation.messages
        streamingText = nil
        // Also store internally for coordination
        internalMessages = conversation.messages.map { mapToInternalMessage($0) }
    }
    
    /// Commit user message synchronously (optimistic render)
    /// Returns the user message that was appended
    @discardableResult
    public func commitMessage() -> UIContracts.UIMessage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let userMessage = UIContracts.UIMessage(role: .user, text: trimmed, createdAt: Date())
        messages.append(userMessage)
        let internalMessage = mapToInternalMessage(userMessage)
        internalMessages.append(internalMessage)
        text = ""
        isSending = true
        
        return userMessage
    }
    
    /// Apply streaming delta update (internal - uses domain types)
    internal func applyDelta(_ delta: AppCoreEngine.ConversationDelta) {
        switch delta {
        case .context:
            // Context updates are handled by workspace view model
            break
        case .assistantStreaming(let aggregate):
            streamingText = aggregate
        case .assistantCommitted(let message):
            streamingText = nil
            let uiMessage = mapToUIMessage(message)
            messages.append(uiMessage)
            internalMessages.append(message)
            isSending = false
        }
    }
    
    /// Finish streaming and finalize assistant message
    public func finishStreaming() {
        if let finalText = streamingText, !finalText.isEmpty {
            let assistantMessage = UIContracts.UIMessage(role: .assistant, text: finalText, createdAt: Date())
            messages.append(assistantMessage)
            let internalMessage = mapToInternalMessage(assistantMessage)
            internalMessages.append(internalMessage)
        }
        streamingText = nil
        isSending = false
    }
    
    /// Legacy send method for backward compatibility
    public func send(conversation: UIContracts.UIConversation, onComplete: @escaping () -> Void) {
        guard let userMessage = commitMessage() else {
            onComplete()
            return
        }
        
        let internalConversation = mapToInternalConversation(conversation)
        Task {
            await coordinator.sendMessage(userMessage.text, in: internalConversation)
            await MainActor.run {
                onComplete()
            }
        }
    }
    
    public func askCodex(conversation: UIContracts.UIConversation, onResult: @escaping (UIContracts.UIConversation) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard coordinator.canAskCodex() else { return }
        isAsking = true
        let internalConversation = mapToInternalConversation(conversation)
        Task {
            let updated = await coordinator.askCodex(trimmed, in: internalConversation)
            await MainActor.run {
                self.isAsking = false
                self.text = ""
                onResult(mapToUIConversation(updated))
            }
        }
    }
    
    // MARK: - Internal Mapping Helpers
    
    private func mapToUIMessage(_ message: AppCoreEngine.Message) -> UIContracts.UIMessage {
        UIContracts.UIMessage(
            id: message.id,
            role: UIContracts.UIMessageRole(rawValue: message.role.rawValue) ?? .user,
            text: message.text,
            createdAt: message.createdAt,
            attachments: message.attachments.map { mapToUIAttachment($0) }
        )
    }
    
    private func mapToInternalMessage(_ message: UIContracts.UIMessage) -> AppCoreEngine.Message {
        AppCoreEngine.Message(
            id: message.id,
            role: AppCoreEngine.MessageRole(rawValue: message.role.rawValue) ?? .user,
            text: message.text,
            createdAt: message.createdAt,
            attachments: message.attachments.map { mapToInternalAttachment($0) }
        )
    }
    
    private func mapToUIAttachment(_ attachment: AppCoreEngine.Attachment) -> UIContracts.UIAttachment {
        switch attachment {
        case .file(let path):
            return .file(path: path)
        case .code(let language, let content):
            return .code(language: language, content: content)
        }
    }
    
    private func mapToInternalAttachment(_ attachment: UIContracts.UIAttachment) -> AppCoreEngine.Attachment {
        switch attachment {
        case .file(let path):
            return .file(path: path)
        case .code(let language, let content):
            return .code(language: language, content: content)
        }
    }
    
    private func mapToUIConversation(_ conversation: AppCoreEngine.Conversation) -> UIContracts.UIConversation {
        UIContracts.UIConversation(
            id: conversation.id,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            messages: conversation.messages.map { mapToUIMessage($0) },
            contextFilePaths: conversation.contextFilePaths,
            contextDescriptorIDs: conversation.contextDescriptorIDs?.map { UIContracts.FileID(rawValue: $0.rawValue) }
        )
    }
    
    private func mapToInternalConversation(_ conversation: UIContracts.UIConversation) -> AppCoreEngine.Conversation {
        AppCoreEngine.Conversation(
            id: conversation.id,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            messages: conversation.messages.map { mapToInternalMessage($0) },
            contextFilePaths: conversation.contextFilePaths,
            contextDescriptorIDs: conversation.contextDescriptorIDs?.map { AppCoreEngine.FileID(rawValue: $0.rawValue) }
        )
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

