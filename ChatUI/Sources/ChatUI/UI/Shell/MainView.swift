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
import UIConnections

struct MainWorkspaceView: View {
    let context: WorkspaceContext
    @ObservedObject var workspaceViewModel: WorkspaceViewModel
    @State private var inspectorTab: InspectorTab = .files
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    init(context: WorkspaceContext) {
        self.context = context
        _workspaceViewModel = ObservedObject(wrappedValue: context.workspaceViewModel)
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
        .animation(.easeInOut, value: context.codexStatusModel.state)
        .toolbar { toolbarItems }
    }
    
    private var navigatorColumn: some View {
        XcodeNavigatorView()
            .environmentObject(workspaceViewModel)
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
        ContextInspector(selectedInspectorTab: $inspectorTab)
            .environmentObject(workspaceViewModel)
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
        if context.codexStatusModel.state != .connected {
            CodexStatusBanner()
                .environmentObject(context.codexStatusModel)
                .environmentObject(workspaceViewModel)
                .padding(.horizontal, DS.s12)
                .padding(.top, DS.s8)
                .transition(.move(edge: .top).combined(with: .opacity))
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
            ChatView(
                workspaceViewModel: workspaceViewModel,
                chatViewModel: context.chatViewModelFactory(UUID()),
                inspectorTab: $inspectorTab
            )
            .navigationTitle(selectedNode.name)
        } else {
            NoFileSelectedView()
                .navigationTitle(
                    context.projectSession.projectName.isEmpty
                        ? "No Selection"
                        : context.projectSession.projectName
                )
        }
    }
}
