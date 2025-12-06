import Foundation
import os.log

protocol DependencyContainer {
    var projectStore: ProjectStore { get }
    var conversationStore: ConversationStore { get }
    var contextPreferencesStore: ContextPreferencesStore { get }
    var preferencesStore: PreferencesStore { get }
    var securityScopeHandler: SecurityScopeHandling { get }
    var workspaceFileSystemService: WorkspaceFileSystemService { get }
    var fileStore: FileStore { get }
    var codexAssistant: CodeAssistant { get }
    var codexConfigLoader: CodexConfigLoading { get }
    var logger: Logger { get }
    var alertCenter: AlertCenter { get }
}

struct DefaultContainer: DependencyContainer {
    let projectStore: ProjectStore
    let conversationStore: ConversationStore
    let contextPreferencesStore: ContextPreferencesStore
    let preferencesStore: PreferencesStore
    let securityScopeHandler: SecurityScopeHandling
    let workspaceFileSystemService: WorkspaceFileSystemService
    let fileStore: FileStore
    let codexAssistant: CodeAssistant
    let codexConfigLoader: CodexConfigLoading
    let logger: Logger
    let alertCenter: AlertCenter
    
    init() {
        self.fileStore = FileStore()
        self.workspaceFileSystemService = WorkspaceFileSystemService(fileManager: .default)
        self.contextPreferencesStore = ContextPreferencesStore()
        self.preferencesStore = PreferencesStore()
        self.securityScopeHandler = RealSecurityScopeHandler()
        self.codexConfigLoader = CodexConfigLoader()
        self.logger = Logger(subsystem: "chat.entelechia", category: "DefaultContainer")
        self.alertCenter = AlertCenter()
        
        // ProjectStore/ConversationStore init kept as existing behavior; container not wired yet.
        self.projectStore = (try? ProjectStore.loadFromDisk()) ?? ProjectStore.inMemoryFallback()
        self.conversationStore = ConversationStore(fileStore: self.fileStore)
        
        if case .success(let config) = codexConfigLoader.loadConfig() {
            self.codexAssistant = CodexAssistant(config: config)
        } else {
            self.codexAssistant = MockCodeAssistant()
        }
    }
}

struct TestContainer: DependencyContainer {
    let projectStore: ProjectStore
    let conversationStore: ConversationStore
    let contextPreferencesStore: ContextPreferencesStore
    let preferencesStore: PreferencesStore
    let securityScopeHandler: SecurityScopeHandling
    let workspaceFileSystemService: WorkspaceFileSystemService
    let fileStore: FileStore
    let codexAssistant: CodeAssistant
    let codexConfigLoader: CodexConfigLoading
    let logger: Logger
    let alertCenter: AlertCenter
    
    init(root: URL) {
        let base = root.appendingPathComponent("Library/Application Support/Entelechia", isDirectory: true)
        self.fileStore = FileStore(baseURL: base)
        self.workspaceFileSystemService = WorkspaceFileSystemService(fileManager: .default)
        self.contextPreferencesStore = ContextPreferencesStore(strict: true)
        self.preferencesStore = PreferencesStore(strict: true)
        self.securityScopeHandler = NoopSecurityScopeHandler()
        self.codexConfigLoader = MockFailingConfigLoader()
        self.logger = Logger(subsystem: "chat.entelechia", category: "TestContainer")
        self.alertCenter = AlertCenter()
        
        self.projectStore = ProjectStore.inMemoryFallback()
        self.conversationStore = ConversationStore(fileStore: self.fileStore)
        self.codexAssistant = MockCodeAssistant()
    }
}

struct NoopSecurityScopeHandler: SecurityScopeHandling {
    func makeBookmark(for url: URL) throws -> Data { Data() }
    func startAccessing(_ url: URL) -> Bool { false }
    func stopAccessing(_ url: URL) {}
}
