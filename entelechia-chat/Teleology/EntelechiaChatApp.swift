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

@main
struct EntelechiaChatApp: App {
    @StateObject private var store: ProjectStore
    @StateObject private var conversationStore = ConversationStore()
    @StateObject private var projectSession: ProjectSession
    @StateObject private var projectCoordinator: ProjectCoordinator
    
    init() {
        // Load ProjectStore from disk BEFORE SwiftUI initializes
        // If database is corrupted, app will crash with clear error message
        let loadedStore: ProjectStore
        do {
            loadedStore = try ProjectStore.loadFromDisk()
            print("✅ Loaded ProjectStore at launch")
        } catch {
            fatalError("❌ Failed to load ProjectStore: \(error.localizedDescription). This is a fatal error - database must be valid.")
        }
        
        _store = StateObject(wrappedValue: loadedStore)
        
        // Create session with loaded store
        let session = ProjectSession(
            projectStore: loadedStore,
            fileSystemService: WorkspaceFileSystemService.shared
        )
        _projectSession = StateObject(wrappedValue: session)
        
        // Create coordinator
        _projectCoordinator = StateObject(wrappedValue: ProjectCoordinator(
            projectStore: loadedStore,
            projectSession: session
        ))
        
        // No auto-open - user must manually select a project
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(conversationStore)
                .environmentObject(projectSession)
                .environmentObject(projectCoordinator)
                .frame(minWidth: 1000, minHeight: 700)
                .task {
                    // Load conversations on startup - if database is corrupted, app will crash
                    do {
                        try conversationStore.loadAll()
                    } catch {
                        fatalError("❌ Failed to load conversations: \(error.localizedDescription). This is a fatal error - database must be valid.")
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
                            // If save fails, crash - no silent errors
                            do {
                                try projectCoordinator.projectStore.clearRecentProjects()
                            } catch {
                                fatalError("❌ Failed to clear recent projects: \(error.localizedDescription). This is a fatal error - database must be valid.")
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
