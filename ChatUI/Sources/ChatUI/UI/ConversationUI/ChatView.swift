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
import UIConnections
import AppKit

struct ChatView: View {
    @ObservedObject var workspaceViewModel: WorkspaceViewModel
    @ObservedObject var chatViewModel: ChatViewModel
    @State private var conversation: Conversation = Conversation(contextFilePaths: [])
    @State private var showMessageContextPopover = false
    @State private var contextPopoverData: ContextBuildResult?
    @Binding private var selectedInspectorTab: InspectorTab
    
    init(
        workspaceViewModel: WorkspaceViewModel,
        chatViewModel: ChatViewModel,
        inspectorTab: Binding<InspectorTab>
    ) {
        self.workspaceViewModel = workspaceViewModel
        self.chatViewModel = chatViewModel
        _selectedInspectorTab = inspectorTab
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ChatMessagesList(
                messages: chatViewModel.messages,
                streamingText: chatViewModel.streamingText ?? "",
                isLoading: chatViewModel.isSending,
                onMessageContext: { handleMessageContext($0) },
                onReask: { reask($0) },
                emptyView: AnyView(emptyState)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.editorBackground)
            .safeAreaInset(edge: .bottom) { footer }
            .onChange(of: conversation.id) { _, _ in
                // Load conversation messages into view model when conversation changes
                chatViewModel.loadConversation(conversation)
            }
            .onAppear {
                // Load initial conversation
                chatViewModel.loadConversation(conversation)
            }
        }
    }
    
    private var footer: some View {
        ChatFooter(
            contextSnapshot: workspaceViewModel.lastContextSnapshot,
            activeScope: chatViewModel.contextScope,
            onViewDetails: { selectedInspectorTab = .context },
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
            text: $chatViewModel.text,
            isAskEnabled: workspaceViewModel.selectedNode != nil,
            isSending: chatViewModel.isSending || chatViewModel.isAsking,
            modelSelection: Binding(
                get: { chatViewModel.model },
                set: { chatViewModel.selectModel($0) }
            ),
            scopeSelection: Binding(
                get: { chatViewModel.contextScope },
                set: { chatViewModel.selectScope($0) }
            ),
            onSend: { sendMessage() },
            onAsk: { askCodex() },
            onAttach: { },
            onMic: { }
        )
    }
    
    private var emptyState: some View {
        ChatEmptyStateView(
            selectedNode: workspaceViewModel.selectedNode,
            onQuickAction: { chatViewModel.text = $0 }
        )
    }
    
    private func sendMessage() {
        // Commit message optimistically (appears instantly in UI)
        guard let userMessage = chatViewModel.commitMessage() else { return }
        
        // Start streaming through coordinator
        Task { @MainActor in
            await chatViewModel.coordinator.stream(userMessage.text, in: conversation)
            
            // Refresh conversation after streaming completes
            if let descriptorID = workspaceViewModel.selectedDescriptorID,
               let refreshed = await workspaceViewModel.conversation(forDescriptorID: descriptorID) {
                conversation = refreshed
                chatViewModel.loadConversation(refreshed)
            } else {
                let targetURL = workspaceViewModel.selectedNode?.path
                    ?? conversation.contextURL
                    ?? conversation.contextFilePaths.first.map { URL(fileURLWithPath: $0) }
                if let url = targetURL {
                    let refreshed = await workspaceViewModel.conversation(for: url)
                    conversation = refreshed
                    chatViewModel.loadConversation(refreshed)
                }
            }
        }
    }
    
    private func askCodex() {
        chatViewModel.askCodex(conversation: conversation) { updated in
            conversation = updated
        }
    }
    
    private var currentStreamingText: String {
        workspaceViewModel.streamingText(for: conversation.id)
    }
    
    private func reask(_ message: Message) {
        let text = message.text
        Task { @MainActor in
            chatViewModel.text = text
            let updated = await workspaceViewModel.askCodex(text, for: conversation)
            conversation = updated
        }
    }
    
    private func handleMessageContext(_ message: Message) {
        if let ctx = workspaceViewModel.contextForMessage(message.id) {
            contextPopoverData = ctx
            showMessageContextPopover = true
        }
    }
}
