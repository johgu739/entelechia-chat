import Foundation
import UIContracts

/// Immutable view state for context UI (pure form, no power).
/// Derived from WorkspaceConversationBindingViewModel, never mutated directly.
/// NOTE: This is a duplicate definition that should be removed. Use UIContracts.ContextViewState instead.
@available(*, deprecated, message: "Use UIContracts.ContextViewState instead")
public struct ContextViewState {
    public let lastContextSnapshot: UIContracts.ContextSnapshot?
    public let lastContextResult: UIContracts.UIContextBuildResult?
    public let streamingMessages: [UUID: String]
    public let bannerMessage: String?
    
    public init(
        lastContextSnapshot: UIContracts.ContextSnapshot?,
        lastContextResult: UIContracts.UIContextBuildResult?,
        streamingMessages: [UUID: String],
        bannerMessage: String?
    ) {
        self.lastContextSnapshot = lastContextSnapshot
        self.lastContextResult = lastContextResult
        self.streamingMessages = streamingMessages
        self.bannerMessage = bannerMessage
    }
}


