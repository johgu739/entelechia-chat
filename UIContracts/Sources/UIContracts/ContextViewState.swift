import Foundation

/// Immutable view state for context UI (pure form, no power).
public struct ContextViewState: Equatable, Sendable {
    public let lastContextSnapshot: ContextSnapshot?
    public let lastContextResult: UIContextBuildResult?
    public let streamingMessages: [UUID: String]
    public let bannerMessage: String?
    public let contextByMessageID: [UUID: UIContextBuildResult]
    
    public init(
        lastContextSnapshot: ContextSnapshot?,
        lastContextResult: UIContextBuildResult?,
        streamingMessages: [UUID: String],
        bannerMessage: String?,
        contextByMessageID: [UUID: UIContextBuildResult] = [:]
    ) {
        self.lastContextSnapshot = lastContextSnapshot
        self.lastContextResult = lastContextResult
        self.streamingMessages = streamingMessages
        self.bannerMessage = bannerMessage
        self.contextByMessageID = contextByMessageID
    }
    
    /// Get context for a specific message ID.
    public func contextForMessage(_ messageID: UUID) -> UIContextBuildResult? {
        contextByMessageID[messageID]
    }
}

