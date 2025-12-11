import Foundation
import AppCoreEngine
import AppAdapters
import UIConnections

public struct AppContainer {
    public struct Engines {
        public let workspace: WorkspaceEngine
        public let project: ProjectEngine
        public let conversation: ConversationStreaming
    }

    public let securityScope: SecurityScopeHandling
    public let codexStatus: CodexAvailability
    public let alertCenter: AlertCenter
    public let projectTodosLoader: ProjectTodosLoading
    public let projectMetadataHandler: ProjectMetadataHandling
    public let codexService: CodexService
    public let engines: Engines

    public init(
        baseURL: URL? = nil,
        forTesting: Bool = false
    ) {
        // Adapters (UI-free)
        let securityScope = SecurityScopeService()
        let fileSystemAccess = FileSystemAccessAdapter()
        let fileContentLoader = FileContentLoaderAdapter(fileManager: .default)
        let fileWatcher = FileSystemWatcherAdapter()
        let projectPersistence = ProjectStoreRealAdapter(baseURL: baseURL)
        let conversationPersistence = FileStoreConversationPersistence(baseURL: baseURL)
        let preferencesDriver = PreferencesStoreAdapter<WorkspacePreferences>(
            strict: forTesting
        )
        let contextPreferencesDriver = ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>(
            strict: forTesting
        )
        let projectTodosLoader = ProjectTodosLoaderAdapter()
        let projectMetadataHandler = ProjectMetadataAdapter()

        // Engines
        let workspaceEngine = WorkspaceEngineImpl(
            fileSystem: fileSystemAccess,
            preferences: preferencesDriver,
            contextPreferences: contextPreferencesDriver,
            watcher: fileWatcher
        )
        let projectEngine = ProjectEngineImpl(persistence: projectPersistence)

        // Codex client
        let codexBuild = AppContainer.makeCodexClient(loader: CodexConfigLoader())

        let conversationEngine = ConversationEngineLive(
            client: codexBuild.client,
            persistence: conversationPersistence,
            fileLoader: fileContentLoader
        )
        let mutationAuthority = FileMutationAuthority()
        let retryPolicy = RetryPolicyImpl()
        let codexService = CodexService(
            conversationEngine: ConversationEngineBox(engine: conversationEngine),
            workspaceEngine: workspaceEngine,
            codexClient: codexBuild.client,
            fileLoader: fileContentLoader,
            retryPolicy: retryPolicy,
            mutationAuthority: mutationAuthority
        )

        self.securityScope = securityScope
        self.alertCenter = AlertCenter()
        self.codexStatus = AppContainer.mapStatus(codexBuild.status)
        self.projectTodosLoader = projectTodosLoader
        self.projectMetadataHandler = projectMetadataHandler
        self.codexService = codexService
        self.engines = Engines(
            workspace: workspaceEngine,
            project: projectEngine,
            conversation: ConversationEngineBox(engine: conversationEngine)
        )
    }
}

// MARK: - Codex client factory
private extension AppContainer {
    enum InternalCodexStatus {
        case connected
        case degradedStub
        case misconfigured(Error)
    }

    static func makeCodexClient(loader: CodexConfigLoading) -> (client: AnyCodexClient, status: InternalCodexStatus) {
        switch loader.loadConfig() {
        case .success(let config):
            let bridge = CodexConfigBridge(
                apiKey: config.apiKey,
                organization: config.organization,
                baseURL: config.baseURL
            )
            let apiAdapter = CodexAPIClientAdapter(config: bridge)
            return (
                AnyCodexClient { messages, files in
                    try await apiAdapter.stream(messages: messages, contextFiles: files)
                },
                .connected
            )

        case .failure(let error):
            return (AnyCodexClient.stub(), .misconfigured(error))
        }
    }

    static func mapStatus(_ status: InternalCodexStatus) -> CodexAvailability {
        switch status {
        case .connected: return .connected
        case .degradedStub: return .degradedStub
        case .misconfigured(let error): return .misconfigured(error)
        }
    }
}

