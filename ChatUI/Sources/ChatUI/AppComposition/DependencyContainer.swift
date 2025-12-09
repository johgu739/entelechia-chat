import Foundation
import AppCoreEngine
import UIConnections
import AppAdapters // Composition root only

protocol DependencyContainer {
    var securityScopeHandler: SecurityScopeHandling { get }
    var codexStatus: CodexAvailability { get }
    var alertCenter: AlertCenter { get }
    var workspaceEngine: WorkspaceEngine { get }
    var projectEngine: ProjectEngine { get }
    var conversationEngine: ConversationStreaming { get }
    var projectTodosLoader: ProjectTodosLoading { get }
    var projectMetadataHandler: ProjectMetadataHandling { get }
}

enum CodexAvailability {
    case connected
    case degradedStub
    case misconfigured(Error)
}

struct DefaultContainer: DependencyContainer {
    let securityScopeHandler: SecurityScopeHandling
    let codexStatus: CodexAvailability
    let alertCenter: AlertCenter
    let workspaceEngine: WorkspaceEngine
    let projectEngine: ProjectEngine
    let conversationEngine: ConversationStreaming
    let projectTodosLoader: ProjectTodosLoading
    let projectMetadataHandler: ProjectMetadataHandling
    
    init() {
        let bootstrap = AppBootstrap()
        self.securityScopeHandler = bootstrap.securityScope
        self.alertCenter = bootstrap.alertCenter
        self.codexStatus = bootstrap.codexStatus
        self.workspaceEngine = bootstrap.engines.workspace
        self.projectEngine = bootstrap.engines.project
        self.conversationEngine = bootstrap.engines.conversation
        self.projectTodosLoader = bootstrap.projectTodosLoader
        self.projectMetadataHandler = bootstrap.projectMetadataHandler
    }
}

struct TestContainer: DependencyContainer {
    let securityScopeHandler: SecurityScopeHandling
    let codexStatus: CodexAvailability
    let alertCenter: AlertCenter
    let workspaceEngine: WorkspaceEngine
    let projectEngine: ProjectEngine
    let conversationEngine: ConversationStreaming
    let projectTodosLoader: ProjectTodosLoading
    let projectMetadataHandler: ProjectMetadataHandling
    
    init(root: URL) {
        let bootstrap = AppBootstrap(baseURL: root, forTesting: true)
        self.securityScopeHandler = bootstrap.securityScope
        self.alertCenter = bootstrap.alertCenter
        self.codexStatus = bootstrap.codexStatus
        self.workspaceEngine = bootstrap.engines.workspace
        self.projectEngine = bootstrap.engines.project
        self.conversationEngine = bootstrap.engines.conversation
        self.projectTodosLoader = bootstrap.projectTodosLoader
        self.projectMetadataHandler = bootstrap.projectMetadataHandler
    }
}

// MARK: - Engine-facing codex client adapter type eraser

struct AnyCodexClient: AppCoreEngine.CodexClient {
    typealias MessageType = Message
    typealias ContextFileType = AppCoreEngine.LoadedFile
    typealias OutputPayload = ModelResponse

    private let streamHandler: @Sendable ([MessageType], [ContextFileType]) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error>

    init(_ streamHandler: @escaping @Sendable ([MessageType], [ContextFileType]) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error>) {
        self.streamHandler = streamHandler
    }

    func stream(
        messages: [MessageType],
        contextFiles: [ContextFileType]
    ) async throws -> AsyncThrowingStream<AppCoreEngine.StreamChunk<OutputPayload>, Error> {
        try await streamHandler(messages, contextFiles)
    }
}

extension AnyCodexClient {
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

private extension DefaultContainer {}

