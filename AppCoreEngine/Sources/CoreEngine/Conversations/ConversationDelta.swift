import Foundation

/// High-level streaming deltas emitted by the ConversationEngine.
public enum ConversationDelta: Sendable {
    /// Context budgeting/attachment decision.
    case context(ContextBuildResult)
    /// Assistant streaming text (aggregate so far).
    case assistantStreaming(String)
    /// Assistant final committed message.
    case assistantCommitted(Message)
}


