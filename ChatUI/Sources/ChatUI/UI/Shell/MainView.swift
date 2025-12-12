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
import UIContracts

struct MainWorkspaceView: View {
    let workspaceState: UIContracts.WorkspaceUIViewState
    let contextState: UIContracts.ContextViewState
    let presentationState: UIContracts.PresentationViewState
    let chatState: UIContracts.ChatViewState
    let filePreviewState: (content: String?, isLoading: Bool, error: Error?)
    let fileStatsState: (size: Int64?, lineCount: Int?, tokenEstimate: Int?, isLoading: Bool)
    let folderStatsState: (stats: UIContracts.FolderStats?, isLoading: Bool)
    let onWorkspaceIntent: (UIContracts.WorkspaceIntent) -> Void
    let onChatIntent: (UIContracts.ChatIntent) -> Void
    let isPathIncludedInContext: (URL) -> Bool
    
    @State private var inspectorTab: UIContracts.InspectorTab = .files
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    init(
        workspaceState: UIContracts.WorkspaceUIViewState,
        contextState: UIContracts.ContextViewState,
        presentationState: UIContracts.PresentationViewState,
        chatState: UIContracts.ChatViewState,
        filePreviewState: (content: String?, isLoading: Bool, error: Error?),
        fileStatsState: (size: Int64?, lineCount: Int?, tokenEstimate: Int?, isLoading: Bool),
        folderStatsState: (stats: UIContracts.FolderStats?, isLoading: Bool),
        onWorkspaceIntent: @escaping (UIContracts.WorkspaceIntent) -> Void,
        onChatIntent: @escaping (UIContracts.ChatIntent) -> Void,
        isPathIncludedInContext: @escaping (URL) -> Bool
    ) {
        self.workspaceState = workspaceState
        self.contextState = contextState
        self.presentationState = presentationState
        self.chatState = chatState
        self.filePreviewState = filePreviewState
        self.fileStatsState = fileStatsState
        self.folderStatsState = folderStatsState
        self.onWorkspaceIntent = onWorkspaceIntent
        self.onChatIntent = onChatIntent
        self.isPathIncludedInContext = isPathIncludedInContext
    }
    
    var body: some View {
        navigationLayout
            .background(AppTheme.windowBackground)
    }
    
    private var navigationLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            navigatorColumn
        } content: {
            chatColumn
        } detail: {
            inspectorColumn
        }
        .overlay(statusOverlay, alignment: .top)
        .toolbar { toolbarItems }
    }
    
    private var navigatorColumn: some View {
        XcodeNavigatorView(
            workspaceState: workspaceState,
            onWorkspaceIntent: onWorkspaceIntent
        )
        .navigationSplitViewColumnWidth(
            min: DS.s20 * CGFloat(10),
            ideal: DS.s20 * CGFloat(12),
            max: DS.s20 * CGFloat(16)
        )
    }
    
    private var chatColumn: some View {
        chatContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var inspectorColumn: some View {
        ContextInspector(
            workspaceState: workspaceState,
            contextState: contextState,
            filePreviewState: filePreviewState,
            fileStatsState: fileStatsState,
            folderStatsState: folderStatsState,
            selectedInspectorTab: $inspectorTab,
            onWorkspaceIntent: onWorkspaceIntent,
            isPathIncludedInContext: isPathIncludedInContext
        )
            .navigationSplitViewColumnWidth(
                min: DS.s20 * CGFloat(11),
                ideal: DS.s20 * CGFloat(13),
                max: DS.s20 * CGFloat(16)
            )
    }
    
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button { toggleSidebar() } label: {
                Image(systemName: "sidebar.leading")
                    .foregroundColor(isSidebarVisible ? .primary : .secondary)
            }
            .help("Toggle File Explorer")
        }
        
        ToolbarItem(placement: .automatic) {
            Button { toggleInspector() } label: {
                Image(systemName: "sidebar.trailing")
                    .foregroundColor(isInspectorVisible ? .primary : .secondary)
            }
            .help("Toggle Inspector")
        }
    }
    
    @ViewBuilder
    private var statusOverlay: some View {
        // Status overlay - CodexStatusBanner needs refactoring to use ViewState
        // For now, this is a placeholder
        EmptyView()
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
        if let selectedNode = workspaceState.selectedNode {
            ChatView(
                chatState: chatState,
                workspaceState: workspaceState,
                contextState: contextState,
                onChatIntent: onChatIntent,
                onWorkspaceIntent: onWorkspaceIntent,
                inspectorTab: $inspectorTab
            )
            .navigationTitle(selectedNode.name)
        } else {
            NoFileSelectedView()
            .navigationTitle("No Selection")
        }
    }
}
