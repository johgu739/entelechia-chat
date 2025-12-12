import Foundation
import AppCoreEngine

/// Immutable view state for chat UI (pure form, no power).
/// Derived from ChatViewModel, never mutated directly.
public struct ChatViewState {
    public let text: String
    public let messages: [Message]
    public let streamingText: String?
    public let isSending: Bool
    public let isAsking: Bool
    public let model: ModelChoice
    public let contextScope: ContextScopeChoice
    
    public init(
        text: String,
        messages: [Message],
        streamingText: String?,
        isSending: Bool,
        isAsking: Bool,
        model: ModelChoice,
        contextScope: ContextScopeChoice
    ) {
        self.text = text
        self.messages = messages
        self.streamingText = streamingText
        self.isSending = isSending
        self.isAsking = isAsking
        self.model = model
        self.contextScope = contextScope
    }
}


