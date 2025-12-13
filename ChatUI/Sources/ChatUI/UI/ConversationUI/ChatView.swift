// @EntelechiaHeaderStart
// Signifier: ChatView
// Substance: Conversation UI surface
// Genus: UI view
// Differentia: Displays conversation and input
// Form: Composition of messages and input
// Matter: Conversation model; chat VM bindings
// Powers: Display messages; send interactions
// FinalCause: Let user converse within file context
// Relations: Serves conversation faculty; depends on VM
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import UIContracts
import AppKit

struct ChatView: View {
    let chatState: UIContracts.ChatViewState
    let workspaceState: UIContracts.WorkspaceUIViewState
    let contextState: UIContracts.ContextViewState
    let onChatIntent: (UIContracts.ChatIntent) -> Void
    let onWorkspaceIntent: (UIContracts.WorkspaceIntent) -> Void
    @Binding var selectedInspectorTab: UIContracts.InspectorTab
    
    @State private var showMessageContextPopover = false
    @State private var contextPopoverData: UIContracts.UIContextBuildResult?
    @State private var localText: String = ""
    
    init(
        chatState: UIContracts.ChatViewState,
        workspaceState: UIContracts.WorkspaceUIViewState,
        contextState: UIContracts.ContextViewState,
        onChatIntent: @escaping (UIContracts.ChatIntent) -> Void,
        onWorkspaceIntent: @escaping (UIContracts.WorkspaceIntent) -> Void,
        inspectorTab: Binding<UIContracts.InspectorTab>
    ) {
        self.chatState = chatState
        self.workspaceState = workspaceState
        self.contextState = contextState
        self.onChatIntent = onChatIntent
        self.onWorkspaceIntent = onWorkspaceIntent
        _selectedInspectorTab = inspectorTab
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ChatMessagesList(
                messages: chatState.messages,
                streamingText: chatState.streamingText ?? "",
                isLoading: chatState.isSending,
                onMessageContext: { handleMessageContext($0) },
                onReask: { reask($0) },
                emptyView: AnyView(emptyState)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .safeAreaInset(edge: .bottom) { footer }
        }
    }
    
    private var footer: some View {
        ChatFooter(
            contextSnapshot: contextState.lastContextSnapshot,
            activeScope: chatState.contextScope,
            onViewDetails: { selectedInspectorTab = UIContracts.InspectorTab.context },
            inputBar: chatInputBar,
            contextPopover: contextPopoverData
        )
        .popover(isPresented: $showMessageContextPopover) {
            if let ctx = contextPopoverData {
                ContextPopoverView(context: ctx)
                    .frame(
                        width: DS.s20 * CGFloat(19),
                        height: DS.s20 * CGFloat(16)
                    )
                    .padding()
            }
        }
    }
    
    private var chatInputBar: ChatInputBar {
        ChatInputBar(
            text: Binding(
                get: { localText.isEmpty ? chatState.text : localText },
                set: { localText = $0 }
            ),
            isAskEnabled: workspaceState.selectedNode != nil,
            isSending: chatState.isSending || chatState.isAsking,
            modelSelection: Binding(
                get: { chatState.model },
                set: { onChatIntent(.setModelChoice($0)) }
            ),
            scopeSelection: Binding(
                get: { chatState.contextScope },
                set: { onChatIntent(.setContextScope($0)) }
            ),
            onSend: { sendMessage() },
            onAsk: { askCodex() },
            onAttach: { },
            onMic: { }
        )
    }
    
    private var emptyState: some View {
        ChatEmptyStateView(
            selectedNode: workspaceState.selectedNode,
            onQuickAction: { text in
                localText = text
            }
        )
    }
    
    private func sendMessage() {
        let text = localText.isEmpty ? chatState.text : localText
        let conversationID = workspaceState.selectedNode?.id ?? UUID()
        localText = ""
        onChatIntent(.sendMessage(text, conversationID))
    }
    
    private func askCodex() {
        let text = localText.isEmpty ? chatState.text : localText
        let conversationID = workspaceState.selectedNode?.id ?? UUID()
        localText = ""
        onChatIntent(.askCodex(text, conversationID))
    }
    
    private func reask(_ message: UIContracts.UIMessage) {
        let conversationID = workspaceState.selectedNode?.id ?? UUID()
        onChatIntent(.askCodex(message.text, conversationID))
    }
    
    private func handleMessageContext(_ message: UIContracts.UIMessage) {
        if let ctx = contextState.contextForMessage(message.id) {
            contextPopoverData = ctx
            showMessageContextPopover = true
        }
    }
}
