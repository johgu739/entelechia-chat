import Foundation

/// Engine-owned context input for conversations.
public struct ConversationContextRequest: Sendable {
    public let snapshot: WorkspaceSnapshot?
    public let preferredDescriptorIDs: [FileID]?
    /// Path-based shim for callers that do not yet speak in descriptors.
    public let contextFileURLs: [URL]?
    public let fallbackContextURL: URL?
    public let budget: ContextBudget?

    public init(
        snapshot: WorkspaceSnapshot? = nil,
        preferredDescriptorIDs: [FileID]? = nil,
        contextFileURLs: [URL]? = nil,
        fallbackContextURL: URL? = nil,
        budget: ContextBudget? = nil
    ) {
        self.snapshot = snapshot
        self.preferredDescriptorIDs = preferredDescriptorIDs
        self.contextFileURLs = contextFileURLs
        self.fallbackContextURL = fallbackContextURL
        self.budget = budget
    }
}


