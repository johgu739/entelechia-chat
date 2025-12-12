import SwiftUI
import ChatUI
import UIConnections
import Combine

/// Public entry point for embedding the Chat UI; composition lives here.
public struct ChatUIHost: View {
    @StateObject private var projectSession: ProjectSession
    @StateObject private var projectCoordinator: ProjectCoordinating
    @StateObject private var alertCenter: AlertCenter
    @StateObject private var codexStatusModel: CodexStatusModel
    @StateObject private var workspaceViewModel: WorkspaceViewModel
    @StateObject private var contextPresentationViewModel: ContextPresentationViewModel
    @StateObject private var bindingCoordinator: ContextErrorBindingCoordinator
    @StateObject private var conversationCoordinator: ConversationCoordinator
    
    private let workspaceEngine: WorkspaceEngine
    private let conversationEngine: ConversationStreaming
    private let projectTodosLoader: ProjectTodosLoading
    private let codexService: CodexQuerying
    private let contextSelectionState: ContextSelectionState
    
    public init(container: DependencyContainer = DefaultContainer()) {
        self.workspaceEngine = container.workspaceEngine
        self.conversationEngine = container.conversationEngine
        self.projectTodosLoader = container.projectTodosLoader
        self.codexService = container.codexService
        let contextSelection = ContextSelectionState()
        let workspaceVM = WorkspaceViewModel(
            workspaceEngine: container.workspaceEngine,
            conversationEngine: container.conversationEngine,
            projectTodosLoader: container.projectTodosLoader,
            codexService: container.codexService,
            domainErrorAuthority: container.domainErrorAuthority,
            contextSelection: contextSelection
        )
        _workspaceViewModel = StateObject(wrappedValue: workspaceVM)
        self.contextSelectionState = contextSelection
        
        let alertCenter = container.alertCenter
        _alertCenter = StateObject(wrappedValue: alertCenter)
        
        // Create CodexStatusModel (will be shared with coordinator)
        let codexStatus = CodexStatusModel(availability: ChatUIHost.map(container.codexStatus))
        _codexStatusModel = StateObject(wrappedValue: codexStatus)
        
        let session = ProjectSession(
            projectEngine: container.projectEngine,
            workspaceEngine: container.workspaceEngine,
            securityScopeHandler: container.securityScopeHandler,
            errorAuthority: container.domainErrorAuthority
        )
        _projectSession = StateObject(wrappedValue: session)
        
        _projectCoordinator = StateObject(wrappedValue: createProjectCoordinator(
            projectEngine: container.projectEngine,
            projectSession: session,
            errorAuthority: container.domainErrorAuthority,
            securityScopeHandler: container.securityScopeHandler,
            projectMetadataHandler: container.projectMetadataHandler
        ))
        
        let presentationVM = ContextPresentationViewModel()
        _contextPresentationViewModel = StateObject(wrappedValue: presentationVM)
        
        let coordinator = ContextErrorBindingCoordinator()
        _bindingCoordinator = StateObject(wrappedValue: coordinator)
        
        // Bind context error publisher to presentation view model
        coordinator.bind(
            publisher: container.errorRouter.contextErrorPublisher,
            to: presentationVM
        )
        
        // Create ConversationCoordinator with stable identity
        let conversationCoord = ConversationCoordinator(
            workspace: workspaceVM,
            contextSelection: contextSelection,
            codexStatusModel: codexStatus
        )
        _conversationCoordinator = StateObject(wrappedValue: conversationCoord)
    }
    
    public var body: some View {
        let context = WorkspaceContext(
            workspaceViewModel: workspaceViewModel,
            chatViewModelFactory: { _ in
                let vm = ChatViewModel(
                    coordinator: conversationCoordinator,
                    contextSelection: contextSelectionState
                )
                // Connect coordinator to view model for streaming
                conversationCoordinator.setChatViewModel(vm)
                return vm
            },
            coordinator: conversationCoordinator,
            contextSelectionState: contextSelectionState,
            codexStatusModel: codexStatusModel,
            projectSession: projectSession,
            projectCoordinator: projectCoordinator,
            alertCenter: alertCenter
        )
        
        return RootView(context: context)
            .environmentObject(contextPresentationViewModel)
            .onChange(of: projectSession.activeProjectURL) { _, newURL in
                if let url = newURL {
                    // Explicitly trigger workspace bootstrap when project opens
                    workspaceViewModel.setRootDirectory(url)
                }
            }
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

