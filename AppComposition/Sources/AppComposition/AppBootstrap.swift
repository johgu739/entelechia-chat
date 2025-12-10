import Foundation
import os.log
import AppCoreEngine
import AppAdapters
import UIConnections

struct AppBootstrap {
    struct Engines {
        let workspace: WorkspaceEngine
        let project: ProjectEngine
        let conversation: ConversationStreaming
    }

    let securityScope: SecurityScopeHandling
    let codexStatus: CodexAvailability
    let alertCenter: AlertCenter
    let projectTodosLoader: ProjectTodosLoading
    let projectMetadataHandler: ProjectMetadataHandling
    let codexService: CodexService
    let engines: Engines

    init(baseURL: URL? = nil, forTesting: Bool = false) {
        // Adapters (UI-free)
        let securityScope = SecurityScopeService()
        let fileSystemAccess = FileSystemAccessAdapter()
        let fileContentLoader = FileContentLoaderAdapter(fileManager: .default)
        let fileWatcher = FileSystemWatcherAdapter()
        let projectPersistence = ProjectStoreRealAdapter(baseURL: baseURL)
        let conversationPersistence = FileStoreConversationPersistence(baseURL: baseURL)
        let preferencesDriver = PreferencesStoreAdapter<WorkspacePreferences>(strict: forTesting)
        let contextPreferencesDriver = ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>(strict: forTesting)
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
        let codexBuild = AppBootstrap.makeCodexClient(loader: CodexConfigLoader(), logger: Logger(subsystem: "chat.entelechia", category: "AppBootstrap"))

        let conversationEngine = ConversationEngineLive(
            client: codexBuild.client,
            persistence: conversationPersistence,
            fileLoader: fileContentLoader
        )
        let mutationAuthority = FileMutationAuthority()
        let codexService = CodexService(
            conversationEngine: ConversationEngineBox(engine: conversationEngine),
            workspaceEngine: workspaceEngine,
            codexClient: codexBuild.client,
            fileLoader: fileContentLoader,
            mutationPipeline: CodexMutationPipeline(authority: mutationAuthority)
        )

        self.securityScope = securityScope
        self.alertCenter = AlertCenter()
        self.codexStatus = AppBootstrap.mapStatus(codexBuild.status)
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
private extension AppBootstrap {
    enum InternalCodexStatus {
        case connected
        case degradedStub
        case misconfigured(Error)
    }

    static func makeCodexClient(loader: CodexConfigLoading, logger: Logger) -> (client: AnyCodexClient, status: InternalCodexStatus) {
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
            logger.error("Codex config missing or invalid, falling back to stub: \(error.localizedDescription, privacy: .public)")
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


