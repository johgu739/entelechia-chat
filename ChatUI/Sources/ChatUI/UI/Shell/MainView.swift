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

public struct MainWorkspaceView: View {
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
    @Binding var inspectorTab: UIContracts.InspectorTab
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    public init(
        workspaceState: UIContracts.WorkspaceUIViewState,
        contextState: UIContracts.ContextViewState,
        presentationState: UIContracts.PresentationViewState,
        chatState: UIContracts.ChatViewState,
        filePreviewState: (content: String?, isLoading: Bool, error: Error?),
        fileStatsState: (size: Int64?, lineCount: Int?, tokenEstimate: Int?, isLoading: Bool),
        folderStatsState: (stats: UIContracts.FolderStats?, isLoading: Bool),
        onWorkspaceIntent: @escaping (UIContracts.WorkspaceIntent) -> Void,
        onChatIntent: @escaping (UIContracts.ChatIntent) -> Void,
        isPathIncludedInContext: @escaping (URL) -> Bool,
        inspectorTab: Binding<UIContracts.InspectorTab>
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
        _inspectorTab = inspectorTab
    }
    
    public var body: some View {
        navigationLayout
    }
    
    private var navigationLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            navigatorColumn
        } content: {
            chatColumn
        } detail: {
            inspectorColumn
        }
    }
    
    private var navigatorColumn: some View {
        XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: onWorkspaceIntent
        )
    }
    
    private var chatColumn: some View {
        NavigationStack {
            chatContent
                .navigationTitle(navigationTitle)
        }
    }
    
    private var navigationTitle: String {
        workspaceState.selectedNode?.name ?? "No Selection"
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
    }
    
    @ViewBuilder
    private var statusOverlay: some View {
        // Status overlay - CodexStatusBanner needs refactoring to use ViewState
        // For now, this is a placeholder
        EmptyView()
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
        } else {
            NoFileSelectedView()
        }
    }
}
