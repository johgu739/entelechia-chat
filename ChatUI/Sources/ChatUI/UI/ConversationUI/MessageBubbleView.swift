// @EntelechiaHeaderStart
// Signifier: MessageBubbleView
// Substance: Message bubble UI
// Genus: UI view
// Differentia: Renders single message with role styling
// Form: Bubble layout and styling
// Matter: Message content; role styling
// Powers: Render single message appropriately
// FinalCause: Visually differentiate messages
// Relations: Serves ChatView
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import UIContracts
import AppKit

struct MessageBubbleView: View {
    let message: UIContracts.UIMessage
    let isAssistant: Bool
    var contextSummary: String?
    var errorMessage: String?
    var onViewContext: (() -> Void)?
    var onReask: (() -> Void)?
    
    var body: some View {
        HStack {
            if isAssistant { Spacer().frame(maxWidth: .infinity) }
            bubbleStack
            if !isAssistant { Spacer().frame(maxWidth: .infinity) }
        }
        .padding(.horizontal, DS.s16)
        .padding(.vertical, DS.s8)
    }
    
    private var bubbleStack: some View {
        VStack(alignment: isAssistant ? .leading : .trailing, spacing: DS.s6) {
            MessageBubbleHeader(isAssistant: isAssistant, createdAt: message.createdAt)
            MessageBubbleContent(
                message: message,
                isAssistant: isAssistant,
                contextSummary: contextSummary,
                errorMessage: errorMessage
            )
            MessageBubbleActions(
                text: message.text,
                isAssistant: isAssistant,
                onViewContext: onViewContext,
                onReask: onReask
            )
            .frame(maxWidth: .infinity, alignment: isAssistant ? .leading : .trailing)
        }
        .frame(maxWidth: DS.s20 * CGFloat(38), alignment: isAssistant ? .leading : .trailing)
    }
}
