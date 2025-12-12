import SwiftUI
import Combine
import UIContracts
import ChatUI

/// Screen adapter for chat UI - observes ChatIntentController and feeds ChatUI.
/// Note: This is a simplified adapter. In practice, ChatView needs workspace and context state,
/// so this should be composed within WorkspaceScreen or RootScreen.
@MainActor
public struct ChatScreen: View {
    @ObservedObject private var intentController: ChatIntentController
    let workspaceState: UIContracts.WorkspaceUIViewState
    let contextState: UIContracts.ContextViewState
    let onWorkspaceIntent: (UIContracts.WorkspaceIntent) -> Void
    @Binding var inspectorTab: InspectorTab
    
    public init(
        intentController: ChatIntentController,
        workspaceState: UIContracts.WorkspaceUIViewState,
        contextState: UIContracts.ContextViewState,
        onWorkspaceIntent: @escaping (UIContracts.WorkspaceIntent) -> Void,
        inspectorTab: Binding<InspectorTab>
    ) {
        self.intentController = intentController
        self.workspaceState = workspaceState
        self.contextState = contextState
        self.onWorkspaceIntent = onWorkspaceIntent
        _inspectorTab = inspectorTab
    }
    
    public var body: some View {
        ChatUI.ChatView(
            chatState: intentController.viewState,
            workspaceState: workspaceState,
            contextState: contextState,
            onIntent: { intent in
                intentController.handle(intent)
            },
            onWorkspaceIntent: onWorkspaceIntent,
            inspectorTab: $inspectorTab
        )
    }
}

