import SwiftUI
import UIConnections

struct ChatMessageRow: View {
    let message: Message
    let onMessageContext: () -> Void
    let onReask: () -> Void
    
    var body: some View {
        MessageBubbleView(
            message: message,
            isAssistant: message.role == .assistant,
            contextSummary: nil,
            errorMessage: nil,
            onViewContext: onMessageContext,
            onReask: onReask
        )
        .id(message.id)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
