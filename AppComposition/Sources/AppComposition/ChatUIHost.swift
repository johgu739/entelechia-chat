import SwiftUI
import ChatUI
import UIConnections
import Combine
import AppCoreEngine
import UIContracts

// CoordinatorFactories is public in UIConnections
// Use fully qualified name if needed: UIConnections.CoordinatorFactories

/// Public entry point for embedding the Chat UI; composition lives here.
/// Pure composition layer - wires together domain, adapters, and UI.
@MainActor
public struct ChatUIHost: View {
    // MARK: - Observable State (Only for SwiftUI lifecycle)
    
    @StateObject private var projectSession: ProjectSession
    private let projectCoordinator: ProjectCoordinating
    @StateObject private var alertCenter: AlertCenter
    @StateObject private var codexStatusModel: CodexStatusModel
    
    // MARK: - Coordinators (Internal, not exposed to ChatUI)
    
    private let workspaceCoordinator: any WorkspaceCoordinating
    private let conversationCoordinator: any ConversationCoordinating
    @StateObject private var bindingCoordinator: ContextErrorBindingCoordinator
    
    // MARK: - State for ViewState Derivation
    
    @State private var workspaceUIViewState: UIContracts.WorkspaceUIViewState = .empty
    @State private var contextViewState: UIContracts.ContextViewState = .empty
    @State private var presentationViewState: UIContracts.PresentationViewState = .empty
    @State private var chatViewState: UIContracts.ChatViewState = .empty
    @State private var bannerMessage: String? = nil
    
    // MARK: - Reactive Update Mechanism
    
    private let stateUpdatePublisher: PassthroughSubject<Void, Never>
    
    // MARK: - Dependencies (Stored for coordinator creation)
    
    private let contextSelectionState: ContextSelectionState
    
    public init(container: DependencyContainer? = nil) {
        let container = container ?? DefaultContainer()
        // Create context selection state
        let contextSelection = ContextSelectionState()
        self.contextSelectionState = contextSelection
        
        // Create alert center
        let alertCenter = container.alertCenter
        _alertCenter = StateObject(wrappedValue: alertCenter)
        
        // Create CodexStatusModel
        let codexStatus = CodexStatusModel(availability: ChatUIHost.map(container.codexStatus))
        _codexStatusModel = StateObject(wrappedValue: codexStatus)
        
        // Create project session
        let session = ProjectSession(
            projectEngine: container.projectEngine,
            workspaceEngine: container.workspaceEngine,
            securityScopeHandler: container.securityScopeHandler,
            errorAuthority: container.domainErrorAuthority
        )
        _projectSession = StateObject(wrappedValue: session)
        
        // Create project coordinator (it's ObservableObject, but we store as protocol)
        self.projectCoordinator = createProjectCoordinator(
            projectEngine: container.projectEngine,
            projectSession: session,
            errorAuthority: container.domainErrorAuthority,
            securityScopeHandler: container.securityScopeHandler,
            projectMetadataHandler: container.projectMetadataHandler
        )
        
        // Create reactive update publisher
        let stateUpdatePublisher = PassthroughSubject<Void, Never>()
        self.stateUpdatePublisher = stateUpdatePublisher
        
        // Create workspace coordinator using factory with reactive update callback
        let workspaceCoord = UIConnections.createWorkspaceCoordinator(
            workspaceEngine: container.workspaceEngine,
            conversationEngine: container.conversationEngine,
            codexService: container.codexService,
            projectTodosLoader: container.projectTodosLoader,
            errorAuthority: container.domainErrorAuthority,
            onStateUpdated: {
                stateUpdatePublisher.send()
            }
        )
        // Store as protocol type (not concrete)
        // Note: We can't use @StateObject with protocol types, so we'll need to handle this differently
        // For now, we'll store the coordinator and update state manually
        self.workspaceCoordinator = workspaceCoord
        
        // Create conversation coordinator using factory
        let conversationCoord = UIConnections.createConversationCoordinator(
            workspace: workspaceCoord,
            contextSelection: contextSelection,
            codexStatusModel: codexStatus
        )
        self.conversationCoordinator = conversationCoord
        
        // Create error binding coordinator
        let bindingCoord = ContextErrorBindingCoordinator()
        _bindingCoordinator = StateObject(wrappedValue: bindingCoord)
        
        // Bind context errors to banner message
        // Note: contextErrorPublisher emits String, not Error
        bindingCoord.bindStringPublisher(
            publisher: container.errorRouter.contextErrorPublisher,
            to: { message in
                // Banner message is updated via @Published property
            }
        )
    }
    
    public var body: some View {
        RootView(
            hasActiveProject: projectSession.activeProjectURL != nil,
            recentProjects: projectCoordinator.recentProjects,
            alert: alertCenter.alert.map { error in
                AlertPresentationModifier.AlertItem(
                    title: error.title,
                    message: error.message,
                    recoverySuggestion: error.recoverySuggestion
                )
            },
            onOpenProject: { url, name in
                projectCoordinator.openProject(url: url, name: name)
            },
            onOpenRecent: { project in
                projectCoordinator.openRecent(project)
            },
            onDismissAlert: {
                alertCenter.alert = nil
            },
            workspaceContent: {
                AnyView(workspaceContent)
            }
        )
        // View states are updated via protocol methods, not @Published properties
        // Update on appear and after intents
        .onReceive(bindingCoordinator.bannerMessagePublisher) { message in
            bannerMessage = message
            updateViewStates()
        }
        .onReceive(stateUpdatePublisher) { _ in
            updateViewStates()
        }
        .onChange(of: projectSession.activeProjectURL) { _, newURL in
            if let url = newURL {
                Task {
                    await workspaceCoordinator.openWorkspace(at: url)
                    updateViewStates()
                }
            }
        }
        .onAppear {
            updateViewStates()
        }
        .frame(minWidth: 1000, minHeight: 700)
    }
    
    // MARK: - ViewState Derivation
    
    // INVARIANT 2: Reactive view-state derivation
    // This method must be called only after observer-applied state changes complete.
    // No premature calls before async updates finish.
    private func updateViewStates() {
        // INVARIANT 3: MainActor protection - view state derivation must be on MainActor
        precondition(Thread.isMainThread, "updateViewStates must run on MainActor")
        
        workspaceUIViewState = workspaceCoordinator.deriveWorkspaceUIViewState()
        contextViewState = workspaceCoordinator.deriveContextViewState(bannerMessage: bannerMessage)
        presentationViewState = workspaceCoordinator.derivePresentationViewState()
        chatViewState = conversationCoordinator.deriveChatViewState(text: chatViewState.text)
    }
    
    // MARK: - Workspace Content
    
    @ViewBuilder
    private var workspaceContent: some View {
        MainWorkspaceView(
            workspaceState: workspaceUIViewState,
            contextState: contextViewState,
            presentationState: presentationViewState,
            chatState: chatViewState,
            filePreviewState: (content: nil as String?, isLoading: false, error: nil as Error?),
            fileStatsState: (size: nil as Int64?, lineCount: nil as Int?, tokenEstimate: nil as Int?, isLoading: false),
            folderStatsState: (stats: nil as UIContracts.FolderStats?, isLoading: false),
            onWorkspaceIntent: { (intent: UIContracts.WorkspaceIntent) in
                workspaceCoordinator.handle(intent)
            },
            onChatIntent: { (intent: UIContracts.ChatIntent) in
                Task {
                    await conversationCoordinator.handle(intent)
                    updateViewStates()
                }
            },
            isPathIncludedInContext: { url in
                workspaceCoordinator.isPathIncludedInContext(url)
            }
        )
    }
    
    // MARK: - Helpers
    
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

// MARK: - Empty State Extensions

extension UIContracts.WorkspaceUIViewState {
    static var empty: UIContracts.WorkspaceUIViewState {
        UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )
    }
}

extension UIContracts.ContextViewState {
    static var empty: UIContracts.ContextViewState {
        UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil,
            contextByMessageID: [:]
        )
    }
}

extension UIContracts.PresentationViewState {
    static var empty: UIContracts.PresentationViewState {
        UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )
    }
}

extension UIContracts.ChatViewState {
    static var empty: UIContracts.ChatViewState {
        UIContracts.ChatViewState(
            text: "",
            messages: [],
            streamingText: nil,
            isSending: false,
            isAsking: false,
            model: .codex,
            contextScope: .selection
        )
    }
}
