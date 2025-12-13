import Foundation
import UIContracts

/// Public protocols for coordinator operations.
/// These expose only UIContracts types, hiding internal implementation.
/// Single source of truth for all coordinator protocols.

/// Public protocol for workspace coordination operations.
/// Exposes only UIContracts types + primitives (URL, UUID, String).
@MainActor
public protocol WorkspaceCoordinating {
    func handle(_ intent: UIContracts.WorkspaceIntent)
    func openWorkspace(at url: URL) async
    func isPathIncludedInContext(_ url: URL) -> Bool
    func deriveWorkspaceUIViewState() -> UIContracts.WorkspaceUIViewState
    func deriveContextViewState(bannerMessage: String?) -> UIContracts.ContextViewState
    func derivePresentationViewState() -> UIContracts.PresentationViewState
}

/// Public protocol for conversation coordination operations.
/// Exposes only UIContracts types + primitives.
@MainActor
public protocol ConversationCoordinating {
    func handle(_ intent: UIContracts.ChatIntent) async
    func deriveChatViewState(text: String) -> UIContracts.ChatViewState
}

/// Public protocol for project coordination operations.
/// Exposes only UIContracts types, hiding internal implementation.
@MainActor
public protocol ProjectCoordinating {
    func openProject(url: URL, name: String)
    func closeProject()
    func openRecent(_ project: UIContracts.RecentProject)
    var recentProjects: [UIContracts.RecentProject] { get }
}


