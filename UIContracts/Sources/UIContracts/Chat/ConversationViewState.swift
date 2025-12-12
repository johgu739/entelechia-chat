import Foundation

/// UI-ready conversation state for display/streaming.
public struct ConversationViewState: Sendable, Equatable {
    public let id: UUID
    public let messages: [UIMessage]
    public let streamingText: String
    public let lastContext: UIContextBuildResult?

    public init(
        id: UUID,
        messages: [UIMessage],
        streamingText: String,
        lastContext: UIContextBuildResult?
    ) {
        self.id = id
        self.messages = messages
        self.streamingText = streamingText
        self.lastContext = lastContext
    }
}

