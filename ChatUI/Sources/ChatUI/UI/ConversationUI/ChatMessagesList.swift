import SwiftUI
import UIContracts

struct ChatMessagesList: View {
    let messages: [UIContracts.UIMessage]
    let streamingText: String
    let isLoading: Bool
    let onMessageContext: (UIContracts.UIMessage) -> Void
    let onReask: (UIContracts.UIMessage) -> Void
    let emptyView: AnyView
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.s4) {
                    messageContent
                }
                .padding(.horizontal, DS.s16)
                .padding(.vertical, DS.s20)
                .frame(minHeight: DS.s20 * CGFloat(20))
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onChange(of: messages.count) { _, _ in
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: streamingText) { _, newValue in
                if !newValue.isEmpty {
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var messageContent: some View {
        if messages.isEmpty && streamingText.isEmpty {
            emptyView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, DS.s20 * CGFloat(3))
        } else {
            ForEach(messages) { message in
                ChatMessageRow(
                    message: message,
                    onMessageContext: { onMessageContext(message) },
                    onReask: { onReask(message) }
                )
            }
            
            if !streamingText.isEmpty {
                StreamingChipView(text: streamingText)
                    .id("streaming")
                    .padding(.horizontal, DS.s16)
                    .padding(.vertical, DS.s8)
            }
            
            if isLoading {
                loadingRow
            }
        }
    }
    
    private var loadingRow: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
                .padding(.leading, DS.s16)
                .padding(.top, DS.s16)
            Spacer()
        }
    }
}
