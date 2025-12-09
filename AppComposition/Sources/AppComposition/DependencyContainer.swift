import Foundation
import AppCoreEngine
import AppAdapters

public protocol DependencyContainer {
    var securityScopeHandler: SecurityScopeHandling { get }
    var codexStatus: CodexAvailability { get }
    var alertCenter: AlertCenter { get }
    var workspaceEngine: WorkspaceEngine { get }
    var projectEngine: ProjectEngine { get }
    var conversationEngine: ConversationStreaming { get }
    var projectTodosLoader: ProjectTodosLoading { get }
    var projectMetadataHandler: ProjectMetadataHandling { get }
    var codexService: CodexService { get }
}

public enum CodexAvailability {
    case connected
    case degradedStub
    case misconfigured(Error)
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
    public let codexService: CodexService
    
    public init() {
        let bootstrap = AppBootstrap()
        self.securityScopeHandler = bootstrap.securityScope
        self.alertCenter = bootstrap.alertCenter
        self.codexStatus = bootstrap.codexStatus
        self.workspaceEngine = bootstrap.engines.workspace
        self.projectEngine = bootstrap.engines.project
        self.conversationEngine = bootstrap.engines.conversation
        self.projectTodosLoader = bootstrap.projectTodosLoader
        self.projectMetadataHandler = bootstrap.projectMetadataHandler
        self.codexService = bootstrap.codexService
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
    public let codexService: CodexService
    
    public init(root: URL) {
        let bootstrap = AppBootstrap(baseURL: root, forTesting: true)
        self.securityScopeHandler = bootstrap.securityScope
        self.alertCenter = bootstrap.alertCenter
        self.codexStatus = bootstrap.codexStatus
        self.workspaceEngine = bootstrap.engines.workspace
        self.projectEngine = bootstrap.engines.project
        self.conversationEngine = bootstrap.engines.conversation
        self.projectTodosLoader = bootstrap.projectTodosLoader
        self.projectMetadataHandler = bootstrap.projectMetadataHandler
        self.codexService = bootstrap.codexService
    }
}

// MARK: - Engine-facing codex client adapter type eraser

public struct AnyCodexClient: AppCoreEngine.CodexClient {
    public typealias MessageType = Message
    public typealias ContextFileType = AppCoreEngine.LoadedFile
    public typealias OutputPayload = ModelResponse

    private let streamHandler: @Sendable ([MessageType], [ContextFileType]) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error>

    public init(_ streamHandler: @escaping @Sendable ([MessageType], [ContextFileType]) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error>) {
        self.streamHandler = streamHandler
    }

    public func stream(
        messages: [MessageType],
        contextFiles: [ContextFileType]
    ) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error> {
        try await streamHandler(messages, contextFiles)
    }
}

public extension AnyCodexClient {
    static func stub() -> AnyCodexClient {
        AnyCodexClient { _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(AppCoreEngine.StreamChunk.output(ModelResponse(content: "Stub response")))
                continuation.yield(AppCoreEngine.StreamChunk.done)
                continuation.finish()
            }
        }
    }
}



