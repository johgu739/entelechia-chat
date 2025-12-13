import Foundation

/// High-level streaming deltas for UI (simplified, pure value type).
public enum ConversationDelta: Sendable {
    /// Context budgeting/attachment decision.
    case context(ContextBuildResult)
    /// Assistant streaming text (aggregate so far).
    case assistantStreaming(String)
    /// Assistant final committed message.
    case assistantCommitted(Message)
}


