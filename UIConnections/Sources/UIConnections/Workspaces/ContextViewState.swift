import Foundation
import AppCoreEngine

/// Immutable view state for context UI (pure form, no power).
/// Derived from WorkspaceConversationBindingViewModel, never mutated directly.
public struct ContextViewState {
    public let lastContextSnapshot: ContextSnapshot?
    public let lastContextResult: ContextBuildResult?
    public let streamingMessages: [UUID: String]
    public let bannerMessage: String?
    
    public init(
        lastContextSnapshot: ContextSnapshot?,
        lastContextResult: ContextBuildResult?,
        streamingMessages: [UUID: String],
        bannerMessage: String?
    ) {
        self.lastContextSnapshot = lastContextSnapshot
        self.lastContextResult = lastContextResult
        self.streamingMessages = streamingMessages
        self.bannerMessage = bannerMessage
    }
}


