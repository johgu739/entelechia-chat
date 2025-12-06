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
import CoreEngine
import os.log

@main
struct EntelechiaChatApp: App {
    @StateObject private var projectSession: ProjectSession
    @StateObject private var projectCoordinator: ProjectCoordinator
    @StateObject private var alertCenter: AlertCenter
    private let container: DependencyContainer
    
    init() {
        // Short-circuit for unit tests to avoid launching full app graph.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let testContainer = TestContainer(root: FileManager.default.temporaryDirectory)
            self.container = testContainer
            let alertCenter = testContainer.alertCenter
            _alertCenter = StateObject(wrappedValue: alertCenter)
            
            let testSession = ProjectSession(
                projectEngine: testContainer.projectEngine,
                workspaceEngine: testContainer.workspaceEngine,
                securityScopeHandler: testContainer.securityScopeHandler
            )
            _projectSession = StateObject(wrappedValue: testSession)
            
            _projectCoordinator = StateObject(wrappedValue: ProjectCoordinator(
                projectEngine: testContainer.projectEngine,
                projectSession: testSession,
                alertCenter: alertCenter,
                securityScopeHandler: testContainer.securityScopeHandler
            ))
            return
        }
        
        let container = DefaultContainer()
        self.container = container
        let alertCenter = container.alertCenter
        _alertCenter = StateObject(wrappedValue: alertCenter)
        
        let session = ProjectSession(
            projectEngine: container.projectEngine,
            workspaceEngine: container.workspaceEngine,
            securityScopeHandler: container.securityScopeHandler
        )
        _projectSession = StateObject(wrappedValue: session)
        
        _projectCoordinator = StateObject(wrappedValue: ProjectCoordinator(
            projectEngine: container.projectEngine,
            projectSession: session,
            alertCenter: alertCenter,
            securityScopeHandler: container.securityScopeHandler
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(
                workspaceEngine: container.workspaceEngine,
                conversationEngine: container.conversationEngine
            )
                .environmentObject(projectSession)
                .environmentObject(projectCoordinator)
                .environmentObject(alertCenter)
                .frame(minWidth: 1000, minHeight: 700)
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
