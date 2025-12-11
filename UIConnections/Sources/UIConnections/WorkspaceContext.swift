import Foundation

/// Single injected root dependency object for workspace UI.
/// ChatUI receives only this context; never individual ViewModels, coordinators, or engines.
public struct WorkspaceContext {
    public let workspaceViewModel: WorkspaceViewModel
    public let chatViewModelFactory: (UUID) -> ChatViewModel
    public let coordinator: ConversationCoordinator
    public let contextSelectionState: ContextSelectionState
    public let codexStatusModel: CodexStatusModel
    public let projectSession: ProjectSession
    public let projectCoordinator: ProjectCoordinator
    public let alertCenter: AlertCenter
    
    public init(
        workspaceViewModel: WorkspaceViewModel,
        chatViewModelFactory: @escaping (UUID) -> ChatViewModel,
        coordinator: ConversationCoordinator,
        contextSelectionState: ContextSelectionState,
        codexStatusModel: CodexStatusModel,
        projectSession: ProjectSession,
        projectCoordinator: ProjectCoordinator,
        alertCenter: AlertCenter
    ) {
        self.workspaceViewModel = workspaceViewModel
        self.chatViewModelFactory = chatViewModelFactory
        self.coordinator = coordinator
        self.contextSelectionState = contextSelectionState
        self.codexStatusModel = codexStatusModel
        self.projectSession = projectSession
        self.projectCoordinator = projectCoordinator
        self.alertCenter = alertCenter
    }
}
