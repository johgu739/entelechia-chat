import SwiftUI
import Combine
import UIContracts
import ChatUI

/// Screen adapter for workspace UI - observes WorkspaceIntentController and feeds ChatUI.
@MainActor
public struct WorkspaceScreen: View {
    @ObservedObject private var workspaceController: WorkspaceIntentController
    @ObservedObject private var chatController: ChatIntentController
    
    public init(
        workspaceController: WorkspaceIntentController,
        chatController: ChatIntentController
    ) {
        self.workspaceController = workspaceController
        self.chatController = chatController
    }
    
    public var body: some View {
        ChatUI.MainWorkspaceView(
            workspaceState: workspaceController.workspaceState,
            contextState: workspaceController.contextState,
            presentationState: workspaceController.presentationState,
            chatState: chatController.viewState,
            filePreviewState: workspaceController.filePreviewState,
            fileStatsState: workspaceController.fileStatsState,
            folderStatsState: workspaceController.folderStatsState,
            onWorkspaceIntent: { intent in
                workspaceController.handle(intent)
            },
            onChatIntent: { intent in
                chatController.handle(intent)
            },
            isPathIncludedInContext: { url in
                workspaceController.isPathIncludedInContext(url)
            }
        )
    }
}

