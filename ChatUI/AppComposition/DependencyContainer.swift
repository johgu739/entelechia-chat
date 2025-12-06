import Foundation
import os.log
import CoreEngine
import AppAdapters

typealias WorkspaceEngineLiveType = WorkspaceEngineImpl<PreferencesStoreAdapter<WorkspacePreferences>, ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>>

protocol DependencyContainer {
    var securityScopeHandler: SecurityScopeHandling { get }
    var logger: Logger { get }
    var alertCenter: AlertCenter { get }

    // Engine + Adapter graph
    var fileSystemAccess: FileSystemAccessAdapter { get }
    var fileContentLoader: FileContentLoaderAdapter { get }
    var projectPersistence: ProjectStoreRealAdapter { get }
    var conversationPersistence: FileStoreConversationPersistence { get }
    var preferencesDriver: PreferencesStoreAdapter<WorkspacePreferences> { get }
    var contextPreferencesDriver: ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState> { get }
    var codexClient: AnyCodexClient { get }
    var workspaceEngine: WorkspaceEngineLiveType { get }
    var projectEngine: ProjectEngineImpl<ProjectStoreRealAdapter> { get }
    var conversationEngine: ConversationEngineLive<AnyCodexClient, FileStoreConversationPersistence> { get }
    var alertSink: AlertSink { get }
}

struct DefaultContainer: DependencyContainer {
    let securityScopeHandler: SecurityScopeHandling
    let logger: Logger
    let alertCenter: AlertCenter
    let fileSystemAccess: FileSystemAccessAdapter
    let fileContentLoader: FileContentLoaderAdapter
    let projectPersistence: ProjectStoreRealAdapter
    let conversationPersistence: FileStoreConversationPersistence
    let preferencesDriver: PreferencesStoreAdapter<WorkspacePreferences>
    let contextPreferencesDriver: ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>
    let codexClient: AnyCodexClient
    let workspaceEngine: WorkspaceEngineLiveType
    let projectEngine: ProjectEngineImpl<ProjectStoreRealAdapter>
    let conversationEngine: ConversationEngineLive<AnyCodexClient, FileStoreConversationPersistence>
    let alertSink: AlertSink
    
    init() {
        self.securityScopeHandler = RealSecurityScopeHandler()
        self.logger = Logger(subsystem: "chat.entelechia", category: "DefaultContainer")
        self.alertCenter = AlertCenter()
        self.fileSystemAccess = FileSystemAccessAdapter(fileManager: .default)
        self.fileContentLoader = FileContentLoaderAdapter(fileManager: .default)
        self.projectPersistence = ProjectStoreRealAdapter()
        self.conversationPersistence = FileStoreConversationPersistence()
        self.preferencesDriver = PreferencesStoreAdapter<WorkspacePreferences>()
        self.contextPreferencesDriver = ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>()
        self.workspaceEngine = WorkspaceEngineImpl(
            fileSystem: fileSystemAccess,
            preferences: preferencesDriver,
            contextPreferences: contextPreferencesDriver
        )
        self.projectEngine = ProjectEngineImpl(persistence: projectPersistence)
        self.alertSink = AlertCenterSink(alertCenter: alertCenter)
        
        // Build Codex client (Engine-facing).
        self.codexClient = DefaultContainer.makeCodexClient(loader: CodexConfigLoader())
        self.conversationEngine = ConversationEngineLive(
            client: codexClient,
            persistence: conversationPersistence,
            fileLoader: fileContentLoader
        )
    }
}

struct TestContainer: DependencyContainer {
    let securityScopeHandler: SecurityScopeHandling
    let logger: Logger
    let alertCenter: AlertCenter
    let fileSystemAccess: FileSystemAccessAdapter
    let fileContentLoader: FileContentLoaderAdapter
    let projectPersistence: ProjectStoreRealAdapter
    let conversationPersistence: FileStoreConversationPersistence
    let preferencesDriver: PreferencesStoreAdapter<WorkspacePreferences>
    let contextPreferencesDriver: ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>
    let codexClient: AnyCodexClient
    let workspaceEngine: WorkspaceEngineLiveType
    let projectEngine: ProjectEngineImpl<ProjectStoreRealAdapter>
    let conversationEngine: ConversationEngineLive<AnyCodexClient, FileStoreConversationPersistence>
    let alertSink: AlertSink
    
    init(root: URL) {
        self.securityScopeHandler = NoopSecurityScopeHandler()
        self.logger = Logger(subsystem: "chat.entelechia", category: "TestContainer")
        self.alertCenter = AlertCenter()
        self.fileSystemAccess = FileSystemAccessAdapter(fileManager: .default)
        self.fileContentLoader = FileContentLoaderAdapter(fileManager: .default)
        self.projectPersistence = ProjectStoreRealAdapter(baseURL: root)
        self.conversationPersistence = FileStoreConversationPersistence(baseURL: root)
        self.preferencesDriver = PreferencesStoreAdapter<WorkspacePreferences>(strict: true)
        self.contextPreferencesDriver = ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>(strict: true)
        self.workspaceEngine = WorkspaceEngineImpl(
            fileSystem: fileSystemAccess,
            preferences: preferencesDriver,
            contextPreferences: contextPreferencesDriver
        )
        self.projectEngine = ProjectEngineImpl(persistence: projectPersistence)
        self.alertSink = AlertCenterSink(alertCenter: alertCenter)
        
        self.codexClient = AnyCodexClient.stub()
        self.conversationEngine = ConversationEngineLive(
            client: codexClient,
            persistence: conversationPersistence,
            fileLoader: fileContentLoader
        )
    }
}

struct NoopSecurityScopeHandler: SecurityScopeHandling {
    func makeBookmark(for url: URL) throws -> Data { Data() }
    func startAccessing(_ url: URL) -> Bool { false }
    func stopAccessing(_ url: URL) {}
}

// MARK: - Engine-facing codex client adapter type eraser

struct AnyCodexClient: CodexClient, @unchecked Sendable {
    typealias MessageType = Message
    typealias ContextFileType = LoadedFile
    typealias OutputPayload = ModelResponse

    private let streamHandler: ([MessageType], [ContextFileType]) async throws -> AsyncThrowingStream<StreamChunk<OutputPayload>, Error>

    init(_ streamHandler: @escaping ([MessageType], [ContextFileType]) async throws -> AsyncThrowingStream<StreamChunk<OutputPayload>, Error>) {
        self.streamHandler = streamHandler
    }

    func stream(
        messages: [MessageType],
        contextFiles: [ContextFileType]
    ) async throws -> AsyncThrowingStream<StreamChunk<OutputPayload>, Error> {
        try await streamHandler(messages, contextFiles)
    }
}

extension AnyCodexClient {
    static func stub() -> AnyCodexClient {
        AnyCodexClient { _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.output(ModelResponse(content: "Stub response")))
                continuation.yield(.done)
                continuation.finish()
            }
        }
    }
}

// MARK: - Helpers

private extension DefaultContainer {
    static func makeCodexClient(loader: CodexConfigLoading) -> AnyCodexClient {
        switch loader.loadConfig() {
        case .success(let config):
            let bridge = CodexConfigBridge(
                apiKey: config.apiKey,
                organization: config.organization,
                baseURL: config.baseURL
            )
            let apiAdapter = CodexAPIClientAdapter(config: bridge)
            return AnyCodexClient { messages, files in
                try await apiAdapter.stream(messages: messages, contextFiles: files)
            }

        case .failure:
            return AnyCodexClient.stub()
        }
    }
}

/// Adapter that forwards Engine alert sink calls to the shared `AlertCenter`.
private struct AlertCenterSink: AlertSink {
    let alertCenter: AlertCenter
    func emit(_ error: Error) {
        Task { @MainActor in
            alertCenter.publish(error, fallbackTitle: "Something went wrong")
        }
    }
}
