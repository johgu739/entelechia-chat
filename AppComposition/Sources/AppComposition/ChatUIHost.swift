import SwiftUI
import ChatUI
import UIConnections

/// Public entry point for embedding the Chat UI; composition lives here.
public struct ChatUIHost: View {
    @StateObject private var projectSession: ProjectSession
    @StateObject private var projectCoordinator: ProjectCoordinator
    @StateObject private var alertCenter: AlertCenter
    @StateObject private var codexStatusModel: CodexStatusModel
    
    private let workspaceEngine: WorkspaceEngine
    private let conversationEngine: ConversationStreaming
    private let projectTodosLoader: ProjectTodosLoading
    private let codexService: CodexQuerying
    
    public init(container: DependencyContainer = DefaultContainer()) {
        self.workspaceEngine = container.workspaceEngine
        self.conversationEngine = container.conversationEngine
        self.projectTodosLoader = container.projectTodosLoader
        self.codexService = container.codexService
        
        let alertCenter = container.alertCenter
        _alertCenter = StateObject(wrappedValue: alertCenter)
        _codexStatusModel = StateObject(wrappedValue: CodexStatusModel(availability: ChatUIHost.map(container.codexStatus)))
        
        let session = ProjectSession(
            projectEngine: container.projectEngine,
            workspaceEngine: container.workspaceEngine,
            securityScopeHandler: container.securityScopeHandler
        )
        _projectSession = StateObject(wrappedValue: session)
        
        _projectCoordinator = StateObject(wrappedValue: ProjectCoordinator(
            projectEngine: container.projectEngine,
            projectSession: session,
            alertCenter: alertCenter,
            securityScopeHandler: container.securityScopeHandler,
            projectMetadataHandler: container.projectMetadataHandler
        ))
    }
    
    public var body: some View {
        RootView(
            workspaceEngine: workspaceEngine,
            conversationEngine: conversationEngine,
            projectTodosLoader: projectTodosLoader,
            codexService: codexService
        )
        .environmentObject(projectSession)
        .environmentObject(projectCoordinator)
        .environmentObject(alertCenter)
        .environmentObject(codexStatusModel)
        .frame(minWidth: 1000, minHeight: 700)
    }

    private static func map(_ availability: CodexAvailability) -> CodexStatusModel.State {
        switch availability {
        case .connected:
            return .connected
        case .degradedStub:
            return .degradedStub
        case .misconfigured(let error):
            return .misconfigured(error.localizedDescription)
        }
    }
}

