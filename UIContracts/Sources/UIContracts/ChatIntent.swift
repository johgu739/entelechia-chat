import Foundation

/// Intent types for chat interactions (value types, no mutation).
/// Intents are descriptive, not imperative - they describe what should happen.
public enum ChatIntent: Sendable {
    case sendMessage(String)
    case askCodex(String)
    case updateText(String)
    case clearText
    case selectModel(ModelChoice)
    case selectScope(ContextScopeChoice)
    case loadConversation(Conversation)
    case streamingDelta(ConversationDelta)
    case finishStreaming
}

