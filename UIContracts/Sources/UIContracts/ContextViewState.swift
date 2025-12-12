import Foundation

/// Immutable view state for context UI (pure form, no power).
public struct ContextViewState: Equatable, Sendable {
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

