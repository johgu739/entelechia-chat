import Foundation
import AppCoreEngine
import UIContracts

/// UI-ready conversation state for display/streaming.
/// This is a legacy type - new code should use UIContracts.ConversationViewState.
/// This type is kept for backward compatibility during migration.
@available(*, deprecated, message: "Use UIContracts.ConversationViewState instead")
public struct ConversationViewState: Sendable, Equatable {
    public let id: UUID
    public let messages: [Message]
    public let streamingText: String
    public let lastContext: ContextBuildResult?

    public init(
        id: UUID,
        messages: [Message],
        streamingText: String,
        lastContext: ContextBuildResult?
    ) {
        self.id = id
        self.messages = messages
        self.streamingText = streamingText
        self.lastContext = lastContext
    }
    
    /// Convert to UIContracts.ConversationViewState
    public func toUIContracts() -> UIContracts.ConversationViewState {
        UIContracts.ConversationViewState(
            id: id,
            messages: messages.map(DomainToUIMappers.toUIMessage),
            streamingText: streamingText,
            lastContext: lastContext.map(DomainToUIMappers.toUIContextBuildResult)
        )
    }
}

public enum ConversationDeltaMapper {
    public static func apply(
        to state: ConversationViewState,
        delta: ConversationDelta
    ) -> ConversationViewState {
        switch delta {
        case .context(let context):
            return ConversationViewState(
                id: state.id,
                messages: state.messages,
                streamingText: state.streamingText,
                lastContext: context
            )
        case .assistantStreaming(let aggregate):
            return ConversationViewState(
                id: state.id,
                messages: state.messages,
                streamingText: aggregate,
                lastContext: state.lastContext
            )
        case .assistantCommitted(let message):
            var msgs = state.messages
            msgs.append(message)
            return ConversationViewState(
                id: state.id,
                messages: msgs,
                streamingText: "",
                lastContext: state.lastContext
            )
        }
    }
}

