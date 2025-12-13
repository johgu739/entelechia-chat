import Foundation
import AppCoreEngine
import Combine
import UIContracts

// Protocols are defined in Protocols/CoordinatorProtocols.swift
// ConversationCoordinating protocol is imported from that file

/// Internal workspace surface required for coordinating chat intents.
/// UIConnections uses this internally; external code should not use it.
@MainActor
internal protocol ConversationWorkspaceHandling: AnyObject {
    func sendMessage(_ text: String, for conversation: AppCoreEngine.Conversation) async
    func askCodex(_ text: String, for conversation: AppCoreEngine.Conversation) async -> AppCoreEngine.Conversation
    func setContextScope(_ scope: UIContracts.ContextScopeChoice)
    func setModelChoice(_ model: UIContracts.ModelChoice)
    func canAskCodex() -> Bool
    var streamingMessages: [UUID: String] { get }
}

@MainActor
internal final class ConversationCoordinator: ConversationCoordinating {
    private let workspace: ConversationWorkspaceHandling
    private let contextSelection: ContextSelectionState
    private let codexStatusModel: CodexStatusModel
    private var streamingObservation: AnyCancellable?
    private var currentStreamingConversationID: UUID?
    
    init(
        workspace: ConversationWorkspaceHandling,
        contextSelection: ContextSelectionState,
        codexStatusModel: CodexStatusModel
    ) {
        self.workspace = workspace
        self.contextSelection = contextSelection
        self.codexStatusModel = codexStatusModel
        setupStreamingObservation()
    }
    
    
    private func setupStreamingObservation() {
        // Streaming observation removed - handled by workspace protocol
    }
    
    /// Internal method - sends message through workspace
    internal func sendMessage(_ text: String, in conversation: AppCoreEngine.Conversation) async {
        await workspace.sendMessage(text, for: conversation)
    }
    
    /// Internal method - asks Codex through workspace
    internal func askCodex(_ text: String, in conversation: AppCoreEngine.Conversation) async -> AppCoreEngine.Conversation {
        await workspace.askCodex(text, for: conversation)
    }
    
    public func setScopeChoice(_ choice: UIContracts.ContextScopeChoice) {
        contextSelection.setScopeChoice(choice)
        workspace.setContextScope(choice)
    }
    
    public func setModelChoice(_ choice: UIContracts.ModelChoice) {
        contextSelection.setModelChoice(choice)
        workspace.setModelChoice(choice)
    }
    
    public func scopeChoice() -> UIContracts.ContextScopeChoice {
        contextSelection.scopeChoice
    }
    
    public func modelChoice() -> UIContracts.ModelChoice {
        contextSelection.modelChoice
    }
    
    public func canAskCodex() -> Bool {
        workspace.canAskCodex()
    }
    
    // MARK: - ViewState Derivation (Public API for Composition)
    
    /// Derive ChatViewState from internal state
    public func deriveChatViewState(text: String = "") -> UIContracts.ChatViewState {
        UIContracts.ChatViewState(
            text: text,
            messages: [], // Messages come from conversation, not coordinator
            streamingText: nil, // Streaming handled by workspace
            isSending: false, // Sending state handled by workspace
            isAsking: false, // Asking state handled by workspace
            model: modelChoice(),
            contextScope: scopeChoice()
        )
    }
    
    /// Handle chat intent
    public func handle(_ intent: UIContracts.ChatIntent) async {
        switch intent {
        case .sendMessage(let text, let conversationID):
            let conversation = AppCoreEngine.Conversation(id: conversationID, contextFilePaths: [])
            await sendMessage(text, in: conversation)
        case .askCodex(let text, let conversationID):
            let conversation = AppCoreEngine.Conversation(id: conversationID, contextFilePaths: [])
            _ = await askCodex(text, in: conversation)
        case .setModelChoice(let choice):
            setModelChoice(choice)
        case .setContextScope(let choice):
            setScopeChoice(choice)
        }
    }
}

