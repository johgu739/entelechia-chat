import Foundation

/// Unified stream events emitted by ConversationEngine.
public enum ConversationStreamEvent: Sendable {
    case context(ContextBuildResult)
    case model(StreamChunk<ModelResponse>)
}

