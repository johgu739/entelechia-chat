import Foundation

/// Immutable view state for chat UI (pure form, no power).
public struct ChatViewState: Equatable, Sendable {
    public let text: String
    public let messages: [UIMessage]
    public let streamingText: String?
    public let isSending: Bool
    public let isAsking: Bool
    public let model: ModelChoice
    public let contextScope: ContextScopeChoice
    
    public init(
        text: String,
        messages: [UIMessage],
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

