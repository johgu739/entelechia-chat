import SwiftUI
import UIContracts

struct ChatMessageRow: View {
    let message: UIContracts.UIMessage
    let onMessageContext: () -> Void
    let onReask: () -> Void
    
    var body: some View {
        MessageBubbleView(
            message: message,
            isAssistant: message.role == UIContracts.UIMessageRole.assistant,
            contextSummary: nil,
            errorMessage: nil,
            onViewContext: onMessageContext,
            onReask: onReask
        )
        .id(message.id)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
