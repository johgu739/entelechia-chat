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
import AppComposition

struct MainWorkspaceView: View {
    private let workspaceEngine: WorkspaceEngine
    private let conversationEngine: ConversationStreaming
    private let projectTodosLoader: ProjectTodosLoading
    @EnvironmentObject var projectSession: ProjectSession
    @EnvironmentObject var alertCenter: AlertCenter
    @EnvironmentObject var codexStatusModel: CodexStatusModel
    @StateObject private var workspaceViewModel: WorkspaceViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var conversation: Conversation = Conversation(contextFilePaths: [])

    init(
        workspaceEngine: WorkspaceEngine,
        conversationEngine: ConversationStreaming,
        projectTodosLoader: ProjectTodosLoading
    ) {
        self.workspaceEngine = workspaceEngine
        self.conversationEngine = conversationEngine
        self.projectTodosLoader = projectTodosLoader
        _workspaceViewModel = StateObject(
            wrappedValue: WorkspaceViewModel(
                workspaceEngine: workspaceEngine,
                conversationEngine: conversationEngine,
                projectTodosLoader: projectTodosLoader
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
            chatContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } detail: {
            // RIGHT: Inspector
            ContextInspector()
                .environmentObject(workspaceViewModel)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        }
        .overlay(alignment: .top) {
            CodexStatusBanner()
                .environmentObject(codexStatusModel)
                .environmentObject(workspaceViewModel)
                .padding(.horizontal, 12)
                .padding(.top, 8)
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

    @ViewBuilder
    private var chatContent: some View {
        if let selectedNode = workspaceViewModel.selectedNode {
            ChatView(conversation: conversation)
                .environmentObject(workspaceViewModel)
                .navigationTitle(selectedNode.name)
                .task(id: selectedNode.path) {
                    if let descriptorID = selectedNode.descriptorID {
                        await workspaceViewModel.ensureConversation(forDescriptorID: descriptorID)
                        if let convo = await workspaceViewModel.conversation(forDescriptorID: descriptorID) {
                            conversation = convo
                        }
                    } else {
                        await workspaceViewModel.ensureConversation(for: selectedNode.path)
                        conversation = await workspaceViewModel.conversation(for: selectedNode.path)
                    }
                }
        } else {
            NoFileSelectedView()
                .navigationTitle(projectSession.projectName.isEmpty ? "No Selection" : projectSession.projectName)
        }
    }
}
