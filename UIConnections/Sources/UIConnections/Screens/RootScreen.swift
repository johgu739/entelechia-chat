import SwiftUI
import Combine
import UIContracts
import ChatUI

/// Root screen adapter - observes IntentControllers and derives ViewState for ChatUI.RootView.
/// Handles ProjectSessionViewState and RecentProjectViewState derivation.
@MainActor
public struct RootScreen: View {
    @ObservedObject private var workspaceController: WorkspaceIntentController
    @ObservedObject private var chatController: ChatIntentController
    @ObservedObject private var projectSession: ProjectSession
    @ObservedObject private var projectCoordinator: ProjectCoordinator
    @ObservedObject private var alertCenter: AlertCenter
    @ObservedObject private var workspaceActivityCoordinator: WorkspaceActivityCoordinator
    
    public init(
        workspaceController: WorkspaceIntentController,
        chatController: ChatIntentController,
        projectSession: ProjectSession,
        projectCoordinator: ProjectCoordinator,
        alertCenter: AlertCenter,
        workspaceActivityCoordinator: WorkspaceActivityCoordinator
    ) {
        self.workspaceController = workspaceController
        self.chatController = chatController
        self.projectSession = projectSession
        self.projectCoordinator = projectCoordinator
        self.alertCenter = alertCenter
        self.workspaceActivityCoordinator = workspaceActivityCoordinator
    }
    
    public var body: some View {
        ChatUI.RootView(
            chatState: chatController.viewState,
            workspaceState: workspaceController.workspaceState,
            contextState: workspaceController.contextState,
            presentationState: workspaceController.presentationState,
            filePreviewState: workspaceController.filePreviewState,
            fileStatsState: workspaceController.fileStatsState,
            folderStatsState: workspaceController.folderStatsState,
            alert: mapUserFacingError(alertCenter.alert),
            projectSessionState: deriveProjectSessionViewState(),
            recentProjects: deriveRecentProjectsViewState(),
            onOpenProject: { url, name in
                projectCoordinator.openProject(url: url, name: name)
            },
            onOpenRecent: { projectViewState in
                // Convert UIContracts.RecentProjectViewState to project URL
                // ProjectCoordinator will handle the domain type conversion internally
                let projectURL = projectViewState.url
                projectCoordinator.openProject(url: projectURL, name: projectViewState.name)
            },
            onChatIntent: { intent in
                chatController.handle(intent)
            },
            onWorkspaceIntent: { intent in
                workspaceController.handle(intent)
            },
            onAlertDismiss: {
                alertCenter.alert = nil
            },
            onProjectOpen: { url in
                // Project open triggers workspace opening
                // This should be handled by a workspace activity coordinator
                // For now, we'll need to pass workspaceActivityViewModel or create coordinator
                // Note: This will be handled by the coordinator passed from AppComposition
            },
            onAlert: { error, title in
                alertCenter.publish(error, fallbackTitle: title)
            },
            isPathIncludedInContext: { url in
                workspaceController.isPathIncludedInContext(url)
            }
        )
    }
    
    private func deriveProjectSessionViewState() -> UIContracts.ProjectSessionViewState {
        UIContracts.ProjectSessionViewState(
            activeProjectURL: projectSession.activeProjectURL,
            projectName: projectSession.activeProjectURL?.lastPathComponent ?? "",
            isOpen: projectSession.activeProjectURL != nil
        )
    }
    
    private func deriveRecentProjectsViewState() -> [UIContracts.RecentProjectViewState] {
        projectCoordinator.recentProjects.map { project in
            UIContracts.RecentProjectViewState(
                name: project.representation.name,
                url: URL(fileURLWithPath: project.representation.rootPath),
                lastOpened: nil // RecentProject doesn't expose lastOpened, would need to add
            )
        }
    }
    
    private func mapUserFacingError(_ error: UIConnections.UserFacingError?) -> UIContracts.UserFacingError? {
        guard let error = error else { return nil }
        return UIContracts.UserFacingError(
            id: error.id,
            title: error.title,
            message: error.message,
            recoverySuggestion: error.recoverySuggestion
        )
    }
}

