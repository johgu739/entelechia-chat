// @EntelechiaHeaderStart
// Signifier: EntelechiaChatApp
// Substance: App telos orchestrator
// Genus: Teleological entry point
// Differentia: Composes environment objects and scenes
// Form: Scene setup and dependency composition
// Matter: App state objects; stores; windows
// Powers: Launch; inject dependencies; present root scene
// FinalCause: Order app parts toward chat work
// Relations: Governs coordinators; stores; UI
// CausalityType: Formal
// @EntelechiaHeaderEnd

import SwiftUI
import os.log

@main
struct EntelechiaChatApp: App {
    @StateObject private var store: ProjectStore
    @StateObject private var conversationStore: ConversationStore
    @StateObject private var projectSession: ProjectSession
    @StateObject private var projectCoordinator: ProjectCoordinator
    @StateObject private var appEnvironment: AppEnvironment
    @StateObject private var alertCenter: AlertCenter
    private let container: DependencyContainer
    
    init() {
        // Short-circuit for unit tests to avoid launching full app graph.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let testContainer = TestContainer(root: FileManager.default.temporaryDirectory)
            self.container = testContainer
            let alertCenter = testContainer.alertCenter
            _alertCenter = StateObject(wrappedValue: alertCenter)

            let testStore = testContainer.projectStore
            _store = StateObject(wrappedValue: testStore)
            
            let testSession = ProjectSession(
                projectStore: testStore,
                fileSystemService: testContainer.workspaceFileSystemService,
                securityScopeHandler: testContainer.securityScopeHandler
            )
            _projectSession = StateObject(wrappedValue: testSession)
            
            _projectCoordinator = StateObject(wrappedValue: ProjectCoordinator(
                projectStore: testStore,
                projectSession: testSession,
                alertCenter: alertCenter,
                securityScopeHandler: testContainer.securityScopeHandler
            ))
            
            _conversationStore = StateObject(wrappedValue: testContainer.conversationStore)
            _appEnvironment = StateObject(wrappedValue: AppEnvironment(container: testContainer))
            return
        }
        
        do {
            try PersistenceMigrator().runMigrations()
        } catch {
            let tempAlert = AlertCenter()
            Logger.persistence.error("Migration failed at startup: \(error.localizedDescription, privacy: .public)")
            tempAlert.publish(error, fallbackTitle: "Failed to Run Migrations")
        }
        
        let container = DefaultContainer()
        self.container = container
        let alertCenter = container.alertCenter
        _alertCenter = StateObject(wrappedValue: alertCenter)
        
        _store = StateObject(wrappedValue: container.projectStore)
        
        let session = ProjectSession(
            projectStore: container.projectStore,
            fileSystemService: container.workspaceFileSystemService,
            securityScopeHandler: container.securityScopeHandler
        )
        _projectSession = StateObject(wrappedValue: session)
        
        _projectCoordinator = StateObject(wrappedValue: ProjectCoordinator(
            projectStore: container.projectStore,
            projectSession: session,
            alertCenter: alertCenter,
            securityScopeHandler: container.securityScopeHandler
        ))
        
        _conversationStore = StateObject(wrappedValue: container.conversationStore)
        _appEnvironment = StateObject(wrappedValue: AppEnvironment(container: container))
        
        // No auto-open - user must manually select a project
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(
                assistant: appEnvironment.assistant,
                workspaceFileSystemService: container.workspaceFileSystemService,
                preferencesStore: container.preferencesStore,
                contextPreferencesStore: container.contextPreferencesStore
            )
                .environmentObject(store)
                .environmentObject(conversationStore)
                .environmentObject(projectSession)
                .environmentObject(projectCoordinator)
                .environmentObject(appEnvironment)
                .environmentObject(alertCenter)
                .frame(minWidth: 1000, minHeight: 700)
                .task {
                    // Load conversations on startup - if database is corrupted, app will crash
                    do {
                        try conversationStore.loadAll()
                    } catch {
                        alertCenter.publish(error, fallbackTitle: "Failed to Load Conversations")
                    }
                }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(after: .newItem) {
                Menu("Open Recent") {
                    if projectCoordinator.recentProjects.isEmpty {
                        Text("No Recent Projects")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(projectCoordinator.recentProjects.prefix(10).enumerated()), id: \.element.path) { index, project in
                            Button(action: {
                                projectCoordinator.openRecent(project)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(project.name)
                                        Text(URL(fileURLWithPath: project.path).deletingLastPathComponent().path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if index < 9 {
                                        Text("⌘⇧\(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command, .shift])
                        }
                        
                        Divider()
                        
                        Button("Clear Menu") {
                            do {
                                try projectCoordinator.projectStore.clearRecentProjects()
                            } catch {
                                alertCenter.publish(error, fallbackTitle: "Failed to Clear Recent Projects")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button("Close Project") {
                    projectCoordinator.closeProject()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - Test-only helpers
private struct TestSecurityScopeHandler: SecurityScopeHandling {
    func makeBookmark(for url: URL) throws -> Data { Data() }
    func startAccessing(_ url: URL) -> Bool { false }
    func stopAccessing(_ url: URL) {}
}
