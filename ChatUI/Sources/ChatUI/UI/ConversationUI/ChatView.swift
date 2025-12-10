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
    @State private var conversation: Conversation
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @State private var inputText: String = ""
    @State private var showMessageContextPopover = false
    @State private var showContextPopover = false
    @State private var contextPopoverData: ContextBuildResult?
    
    init(conversation: Conversation) {
        _conversation = State(initialValue: conversation)
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                contextBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                    if conversation.messages.isEmpty && currentStreamingText.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 60)
                    } else {
                        ForEach(conversation.messages) { message in
                                MessageBubbleView(
                                    message: message,
                                    isAssistant: message.role == .assistant,
                                    contextSummary: message.role == .assistant ? contextSummary(for: message) : nil,
                                    errorMessage: nil,
                                    onViewContext: {
                                        if let ctx = workspaceViewModel.contextForMessage(message.id) {
                                            contextPopoverData = ctx
                                            showMessageContextPopover = true
                                        }
                                    },
                                    onReask: {
                                        reask(message)
                                    }
                                )
                                .id(message.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        
                        if !currentStreamingText.isEmpty {
                            StreamingChip(text: "Assistant is thinking…")
                                .id("streaming")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
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
                .onChange(of: conversation.messages.count) { _, _ in
                if let lastMessage = conversation.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
                .onChange(of: currentStreamingText) { _, newValue in
                if !newValue.isEmpty {
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                ChatInputView(
                    text: $inputText,
                    onSend: { sendMessage() },
                    onAttachFile: { /* handled elsewhere */ },
                    onAskCodex: { askCodex() },
                    isAskEnabled: workspaceViewModel.selectedNode != nil,
                    currentTarget: workspaceViewModel.selectedNode?.path.path,
                    sendShortcut: "⌘⏎",
                    askShortcut: "⌥⏎"
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .popover(isPresented: $showMessageContextPopover) {
                    if let ctx = contextPopoverData {
                        contextPopover(ctx)
                            .frame(width: 380, height: 320)
                            .padding()
                    }
                }
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
            if let descriptorID = workspaceViewModel.selectedDescriptorID,
               let refreshed = await workspaceViewModel.conversation(forDescriptorID: descriptorID) {
                conversation = refreshed
            } else {
                let targetURL = workspaceViewModel.selectedNode?.path ?? conversation.contextURL ?? conversation.contextFilePaths.first.map { URL(fileURLWithPath: $0) }
                if let url = targetURL {
                    conversation = await workspaceViewModel.conversation(for: url)
                }
            }
        }
    }

    private func askCodex() {
        let text = inputText
        inputText = ""
        Task { @MainActor in
            let updated = await workspaceViewModel.askCodex(text, for: conversation)
            conversation = updated
        }
    }
    
    private var currentStreamingText: String {
        workspaceViewModel.streamingText(for: conversation.id)
    }
    
    // Per-message context summary placeholder (uses last context result for now)
    private func contextSummary(for message: Message) -> String? {
        guard let ctx = workspaceViewModel.lastContextResult else { return nil }
        let files = ctx.attachments.map { $0.url.lastPathComponent }
        let trimmed = ctx.truncatedFiles.map { $0.url.lastPathComponent }
        var parts: [String] = []
        if !files.isEmpty { parts.append("files: \(files.joined(separator: ", "))") }
        if !trimmed.isEmpty { parts.append("trimmed: \(trimmed.joined(separator: ", "))") }
        if ctx.excludedFiles.count > 0 { parts.append("excluded: \(ctx.excludedFiles.count)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func reask(_ message: Message) {
        let text = message.text
        Task { @MainActor in
            inputText = text
            let updated = await workspaceViewModel.askCodex(text, for: conversation)
            conversation = updated
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
                    quickActions([
                        "Summarize this folder",
                        "List key files in this folder",
                        "Identify risks in this folder"
                    ])
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
                    quickActions([
                        "Summarize this file",
                        "List risky areas in this file",
                        "Explain the main logic in this file"
                    ])
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

    private func quickActions(_ prompts: [String]) -> some View {
        HStack(spacing: 12) {
            ForEach(prompts.prefix(3), id: \.self) { prompt in
                Button(prompt) {
                    inputText = prompt
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 8)
    }

    private var contextBar: some View {
        let target = workspaceViewModel.selectedNode?.name ?? "No selection"
        let ctx = workspaceViewModel.lastContextResult
        let segments = ctx?.encodedSegments.count ?? 0
        let attachments = ctx?.attachments.count ?? 0
        let tokens = ctx?.totalTokens ?? 0
        let bytes = ctx?.totalBytes ?? 0
        return HStack(spacing: 12) {
            Label(target, systemImage: "doc.text.magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(target == "No selection" ? .secondary : .primary)
            Spacer()
            contextMetric("Segments", "\(segments)")
            contextMetric("Files", "\(attachments)")
            contextMetric("Tokens", "\(tokens)")
            contextMetric("Bytes", ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary))
            if let ctx {
                Button {
                    showContextPopover.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showContextPopover) {
                    contextPopover(ctx)
                        .frame(width: 380, height: 320)
                        .padding()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    private func contextMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

    @ViewBuilder
    private func contextPopover(_ ctx: ContextBuildResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Context Sent to Codex")
                .font(.system(size: 14, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ctx.attachments, id: \.id) { file in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.url.lastPathComponent)
                                .font(.system(size: 13, weight: .semibold))
                            Text(file.url.path)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(file.byteCount), countStyle: .binary))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                if let note = file.contextNote {
                                    Text(note)
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                    }
                    if !ctx.truncatedFiles.isEmpty {
                        Divider()
                        Text("Truncated")
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(ctx.truncatedFiles, id: \.id) { file in
                            Text("\(file.url.lastPathComponent) trimmed to \(ByteCountFormatter.string(fromByteCount: Int64(file.byteCount), countStyle: .binary))")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    if !ctx.excludedFiles.isEmpty {
                        Divider()
                        Text("Excluded")
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(ctx.excludedFiles, id: \.id) { exclusion in
                            Text(verbatim: "\(exclusion.file.url.lastPathComponent) – \(exclusion.reason)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
