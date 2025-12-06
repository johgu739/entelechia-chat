// @EntelechiaHeaderStart
// Signifier: MainView
// Substance: Workspace layout view
// Genus: UI shell view
// Differentia: Composes navigator, chat, inspector
// Form: Split view composition rules
// Matter: Workspace VM; session; conversation store
// Powers: Arrange columns; propagate selections
// FinalCause: Provide primary working surface
// Relations: Serves UI; depends on WorkspaceViewModel
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import Engine
import UIConnections
import UIConnections

struct MainWorkspaceView: View {
    private let workspaceEngine: WorkspaceEngine
    private let conversationEngine: ConversationEngineLive<AnyCodexClient, FileStoreConversationPersistence>
    @EnvironmentObject var projectSession: ProjectSession
    @EnvironmentObject var alertCenter: AlertCenter
    @StateObject private var workspaceViewModel: WorkspaceViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(
        workspaceEngine: WorkspaceEngine,
        conversationEngine: ConversationEngineLive<AnyCodexClient, FileStoreConversationPersistence>
    ) {
        self.workspaceEngine = workspaceEngine
        self.conversationEngine = conversationEngine
        _workspaceViewModel = StateObject(
            wrappedValue: WorkspaceViewModel(
                workspaceEngine: workspaceEngine,
                conversationEngine: conversationEngine
            )
        )
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // LEFT: Xcode-like Navigator
            XcodeNavigatorView()
                .environmentObject(workspaceViewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            // CENTER: Chat or No File Selected
            Group {
                if let selectedNode = workspaceViewModel.selectedNode {
                    // Use a computed property to get the latest conversation from store
                    let currentConversation = workspaceViewModel.conversation(for: selectedNode.path)
                    ChatView(conversation: currentConversation)
                        .environmentObject(workspaceViewModel)
                        .navigationTitle(selectedNode.name)
                        .task(id: selectedNode.path) {
                            // Ensure conversation exists asynchronously (outside view rendering)
                            // The conversation returned by workspaceViewModel.conversation(for:) will
                            // automatically reflect updates from ConversationStore since it reads from
                            // the @Published conversations array
                            await workspaceViewModel.ensureConversation(for: selectedNode.path)
                        }
                } else {
                    NoFileSelectedView()
                        .navigationTitle(projectSession.projectName.isEmpty ? "No Selection" : projectSession.projectName)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } detail: {
            // RIGHT: Inspector
            ContextInspector()
                .environmentObject(workspaceViewModel)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        }
        .toolbar {
            // File Explorer toggle
            ToolbarItem(placement: .automatic) {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.leading")
                        .foregroundColor(isSidebarVisible ? .primary : .secondary)
                }
                .help("Toggle File Explorer")
            }
            
            // Inspector toggle
            ToolbarItem(placement: .automatic) {
                Button {
                    toggleInspector()
                } label: {
                    Image(systemName: "sidebar.trailing")
                        .foregroundColor(isInspectorVisible ? .primary : .secondary)
                }
                .help("Toggle Inspector")
            }
        }
        .background(AppTheme.windowBackground)
        .onAppear {
            workspaceViewModel.setAlertCenter(alertCenter)
            projectSession.setAlertCenter(alertCenter)
            if let url = projectSession.activeProjectURL {
                workspaceViewModel.setRootDirectory(url)
            }
        }
        .onChange(of: projectSession.activeProjectURL) { _, newValue in
            if let url = newValue {
                workspaceViewModel.setRootDirectory(url)
            }
        }
    }
    
    private var isSidebarVisible: Bool {
        columnVisibility == .all || columnVisibility == .doubleColumn
    }
    
    private var isInspectorVisible: Bool {
        columnVisibility == .all
    }
    
    private func toggleSidebar() {
        if columnVisibility == .all {
            columnVisibility = .detailOnly
        } else {
            columnVisibility = .all
        }
    }
    
    private func toggleInspector() {
        if columnVisibility == .all {
            columnVisibility = .doubleColumn
        } else {
            columnVisibility = .all
        }
    }
}
