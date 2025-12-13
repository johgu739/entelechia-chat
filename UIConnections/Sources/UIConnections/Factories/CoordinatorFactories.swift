import Foundation
import AppCoreEngine
import UIContracts

// Protocols are defined in Protocols/CoordinatorProtocols.swift

/// Public factory functions for creating coordinators.
/// These return protocol types, hiding internal implementations.

/// Create a workspace coordinator.
/// Returns a protocol that exposes only UIContracts types.
/// Accepts domain engines directly; adapts internally.
/// Note: ConversationEngine has associated types, so we accept the concrete ConversationEngineLive type.
@MainActor
public func createWorkspaceCoordinator<Client: CodexClient, Persistence: ConversationPersistenceDriver>(
    workspaceEngine: WorkspaceEngine,
    conversationEngine: ConversationEngineLive<Client, Persistence>,
    codexService: CodexQuerying,
    projectTodosLoader: ProjectTodosLoading,
    errorAuthority: DomainErrorAuthority
) -> any WorkspaceCoordinating where Client.MessageType == AppCoreEngine.Message,
                                     Client.ContextFileType == AppCoreEngine.LoadedFile,
                                     Client.OutputPayload == AppCoreEngine.ModelResponse,
                                     Persistence.ConversationType == AppCoreEngine.Conversation {
    // Access internal types within same module
    let presentationModel = WorkspacePresentationModel()
    let projection = WorkspaceProjection()
    // Adapt domain engine to internal protocol
    let conversationAdapter = ConversationEngineAdapter(engine: conversationEngine)
    let coordinator = WorkspaceCoordinator(
        workspaceEngine: workspaceEngine,
        conversationEngine: conversationAdapter,
        codexService: codexService,
        projectTodosLoader: projectTodosLoader,
        presentationModel: presentationModel,
        projection: projection,
        errorAuthority: errorAuthority
    )
    // Create and start observer
    let observer = WorkspaceStateObserver(
        workspaceEngine: workspaceEngine,
        presentationModel: presentationModel,
        projection: projection
    )
    // Observer is retained by coordinator's lifecycle
    _ = observer
    return coordinator
}

/// Create a conversation coordinator.
/// Returns a protocol that exposes only UIContracts types.
@MainActor
public func createConversationCoordinator(
    workspace: any WorkspaceCoordinating,
    contextSelection: ContextSelectionState,
    codexStatusModel: CodexStatusModel
) -> any ConversationCoordinating {
    // Cast workspace to internal protocol for coordinator creation
    guard let workspaceCoord = workspace as? ConversationWorkspaceHandling else {
        fatalError("WorkspaceCoordinating must be implemented by WorkspaceCoordinator")
    }
    return ConversationCoordinator(
        workspace: workspaceCoord,
        contextSelection: contextSelection,
        codexStatusModel: codexStatusModel
    )
}

/// Create a project coordinator.
/// Returns a protocol that exposes only UIContracts types.
@MainActor
public func createProjectCoordinator(
    projectEngine: ProjectEngine,
    projectSession: ProjectSessioning,
    errorAuthority: DomainErrorAuthority,
    securityScopeHandler: SecurityScopeHandling,
    projectMetadataHandler: ProjectMetadataHandling
) -> any ProjectCoordinating {
    ProjectCoordinator(
        projectEngine: projectEngine,
        projectSession: projectSession,
        errorAuthority: errorAuthority,
        securityScopeHandler: securityScopeHandler,
        projectMetadataHandler: projectMetadataHandler
    )
}
