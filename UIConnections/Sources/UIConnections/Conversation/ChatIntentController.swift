import Foundation
import Combine
import AppCoreEngine
import UIContracts

/// Intent controller for chat interactions (sole mutation boundary).
/// Owns ChatViewModel and exposes derived ChatViewState.
/// All mutations flow through handle(_ intent:) method.
@MainActor
public final class ChatIntentController: ObservableObject {
    private let viewModel: ChatViewModel
    private let coordinator: ConversationCoordinator
    private var cancellables: Set<AnyCancellable> = []
    
    /// ViewState is computed from ViewModels (single source of truth).
    public var viewState: UIContracts.ChatViewState {
        Self.deriveViewState(from: viewModel)
    }
    
    public init(viewModel: ChatViewModel, coordinator: ConversationCoordinator) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        observeViewModel()
        setupStreamingObservation()
    }
    
    private func setupStreamingObservation() {
        // Set up coordinator to forward streaming updates as intents
        coordinator.setStreamingIntentDispatcher { [weak self] intent in
            self?.handle(intent)
        }
        // Also set viewModel for legacy support
        coordinator.setChatViewModel(viewModel)
        
        // Observe context selection changes and dispatch intents
        viewModel.contextSelection.$modelChoice
            .sink { [weak self] choice in
                guard let self else { return }
                // Only dispatch if different to avoid loops
                if self.viewModel.model != choice {
                    self.handle(.selectModel(choice))
                }
            }
            .store(in: &cancellables)
        
        viewModel.contextSelection.$scopeChoice
            .sink { [weak self] choice in
                guard let self else { return }
                // Only dispatch if different to avoid loops
                if self.viewModel.contextScope != choice {
                    self.handle(.selectScope(choice))
                }
            }
            .store(in: &cancellables)
    }
    
    /// Handle intent - the sole mutation boundary for chat state.
    public func handle(_ intent: UIContracts.ChatIntent) {
        switch intent {
        case .sendMessage(let text, let conversationID):
            // Commit message optimistically (mutation in intent handler)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            let userMessage = viewModel.commitMessage()
            guard let message = userMessage else { return }
            
            // Start streaming through coordinator (internal coordination)
            let internalConversation = AppCoreEngine.Conversation(id: conversationID, contextFilePaths: [])
            Task {
                await coordinator.sendMessage(message.text, in: internalConversation)
            }
            
        case .askCodex(let text, let conversationID):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            let conversation = UIContracts.UIConversation(id: conversationID, contextFilePaths: [])
            viewModel.askCodex(conversation: conversation) { _ in
                // Callback handled, state already updated
            }
            
        case .setModelChoice(let choice):
            viewModel.selectModel(choice)
            
        case .setContextScope(let choice):
            viewModel.selectScope(choice)
        }
    }
    
    private func observeViewModel() {
        // Observe @Published changes and publish objectWillChange (ViewState is computed)
        viewModel.$text
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        viewModel.$messages
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        viewModel.$streamingText
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        viewModel.$isSending
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        viewModel.$isAsking
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        viewModel.$model
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        viewModel.$contextScope
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private static func deriveViewState(from viewModel: ChatViewModel) -> UIContracts.ChatViewState {
        UIContracts.ChatViewState(
            text: viewModel.text,
            messages: viewModel.messages, // Already UIContracts.UIMessage
            streamingText: viewModel.streamingText,
            isSending: viewModel.isSending,
            isAsking: viewModel.isAsking,
            model: viewModel.model, // Already UIContracts.ModelChoice
            contextScope: viewModel.contextScope // Already UIContracts.ContextScopeChoice
        )
    }
}

