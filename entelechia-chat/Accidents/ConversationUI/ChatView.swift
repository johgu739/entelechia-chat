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
import AppKit

struct ChatView: View {
    @State var conversation: Conversation
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @StateObject private var chatViewModel = ChatViewModel(assistant: MockCodeAssistant())
    @State private var inputText: String = ""
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Show empty state if no messages
                    if conversation.messages.isEmpty && chatViewModel.streamingText.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 60)
                    } else {
                        ForEach(conversation.messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        
                        if !chatViewModel.streamingText.isEmpty {
                            ChatAssistantMessageView(text: chatViewModel.streamingText)
                                .id("streaming")
                        }
                        
                        if workspaceViewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.leading, 20)
                                    .padding(.top, 16)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(minHeight: 400)
            }
            .onChange(of: conversation.messages.count) { oldValue, newValue in
                if let lastMessage = conversation.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatViewModel.streamingText) { oldValue, newValue in
                if !newValue.isEmpty {
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                ChatInputView(
                    text: $inputText,
                    onSend: {
                        sendMessage()
                    },
                    onAttachFile: {
                        // File attachment is handled in ContextInspector
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.editorBackground)
    }
    
    private func sendMessage() {
        let text = inputText
        inputText = ""
        
        Task { @MainActor in
            await workspaceViewModel.sendMessage(text, for: conversation)
            // Update local conversation state after message is sent
            // The conversation will be updated via WorkspaceViewModel
            if let updated = workspaceViewModel.conversationStore?.conversations.first(where: { $0.id == conversation.id }) {
                conversation = updated
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        if let selectedNode = workspaceViewModel.selectedNode {
            let isFolder = selectedNode.children != nil && !(selectedNode.children?.isEmpty ?? true)
            
            if isFolder {
                // Folder selected - show summary
                VStack(spacing: 16) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Start chatting about this folder")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if let children = selectedNode.children, !children.isEmpty {
                        let files = children.filter { $0.children == nil || $0.children?.isEmpty == true }
                        Text("\(children.count) items (\(files.count) files)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // File selected - show prompt
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No chat yet for this file")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Start by asking something about this file")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("Select a file or folder to begin chatting")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
}

struct ChatAssistantMessageView: View {
    let text: String
    
    var body: some View {
        MarkdownMessageView(content: text)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .opacity(0.7)
    }
}

struct MessageView: View {
    let message: Message
    
    var body: some View {
        Group {
            if message.role == .user {
                MessageBubbleView(message: message)
            } else {
                // Assistant message with copy button (ChatGPT style)
                MarkdownMessageView(content: message.text)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
        }
    }
}