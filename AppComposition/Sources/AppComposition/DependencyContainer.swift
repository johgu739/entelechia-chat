import Foundation
import UIConnections

public protocol DependencyContainer {
    var securityScopeHandler: SecurityScopeHandling { get }
    var codexStatus: CodexAvailability { get }
    var alertCenter: AlertCenter { get }
    var workspaceEngine: WorkspaceEngine { get }
    var projectEngine: ProjectEngine { get }
    var conversationEngine: ConversationStreaming { get }
    var projectTodosLoader: ProjectTodosLoading { get }
    var projectMetadataHandler: ProjectMetadataHandling { get }
    var codexService: CodexQueryService { get }
    var fileMutationService: FileMutationPlanning { get }
    var fileMutationAuthority: FileMutationAuthorizing { get }
    var domainErrorAuthority: DomainErrorAuthority { get }
    var errorRouter: UIPresentationErrorRouter { get }
}

public struct DefaultContainer: DependencyContainer {
    public let securityScopeHandler: SecurityScopeHandling
    public let codexStatus: CodexAvailability
    public let alertCenter: AlertCenter
    public let workspaceEngine: WorkspaceEngine
    public let projectEngine: ProjectEngine
    public let conversationEngine: ConversationStreaming
    public let projectTodosLoader: ProjectTodosLoading
    public let projectMetadataHandler: ProjectMetadataHandling
    public let codexService: CodexQueryService
    public let fileMutationService: FileMutationPlanning
    public let fileMutationAuthority: FileMutationAuthorizing
    
    public init() {
        let container = AppContainer()
        self.securityScopeHandler = container.securityScope
        self.alertCenter = container.alertCenter
        self.codexStatus = container.codexStatus
        self.workspaceEngine = container.engines.workspace
        self.projectEngine = container.engines.project
        self.conversationEngine = container.engines.conversation
        self.projectTodosLoader = container.projectTodosLoader
        self.projectMetadataHandler = container.projectMetadataHandler
        self.codexService = container.codexService
        self.fileMutationService = container.fileMutationService
        self.fileMutationAuthority = container.fileMutationAuthority
        self.domainErrorAuthority = container.domainErrorAuthority
        self.errorRouter = container.errorRouter
    }
}

public struct TestContainer: DependencyContainer {
    public let securityScopeHandler: SecurityScopeHandling
    public let codexStatus: CodexAvailability
    public let alertCenter: AlertCenter
    public let workspaceEngine: WorkspaceEngine
    public let projectEngine: ProjectEngine
    public let conversationEngine: ConversationStreaming
    public let projectTodosLoader: ProjectTodosLoading
    public let projectMetadataHandler: ProjectMetadataHandling
    public let codexService: CodexQueryService
    public let fileMutationService: FileMutationPlanning
    public let fileMutationAuthority: FileMutationAuthorizing
    
    public init(root: URL) {
        let container = AppContainer(baseURL: root, forTesting: true)
        self.securityScopeHandler = container.securityScope
        self.alertCenter = container.alertCenter
        self.codexStatus = container.codexStatus
        self.workspaceEngine = container.engines.workspace
        self.projectEngine = container.engines.project
        self.conversationEngine = container.engines.conversation
        self.projectTodosLoader = container.projectTodosLoader
        self.projectMetadataHandler = container.projectMetadataHandler
        self.codexService = container.codexService
        self.fileMutationService = container.fileMutationService
        self.fileMutationAuthority = container.fileMutationAuthority
        self.domainErrorAuthority = container.domainErrorAuthority
        self.errorRouter = container.errorRouter
    }
}

