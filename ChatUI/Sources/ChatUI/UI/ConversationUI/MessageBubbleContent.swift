import SwiftUI
import UIContracts

struct MessageBubbleContent: View {
    let message: UIContracts.UIMessage
    let isAssistant: Bool
    let contextSummary: String?
    let errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.s8) {
            if let contextSummary, !contextSummary.isEmpty, isAssistant {
                Text(contextSummary)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            if let errorMessage, !errorMessage.isEmpty {
                errorRow(errorMessage)
            }
            MarkdownMessageView(content: message.text)
        }
        .padding(.horizontal, DS.s16)
        .padding(.vertical, DS.s12)
        .background(bubbleBackground)
        .frame(maxWidth: DS.s16 * CGFloat(45), alignment: .leading)
    }
    
    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: DS.r16)
            .fill(isAssistant ? DS.background : DS.background.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: DS.r16)
                    .stroke(DS.stroke, lineWidth: 1)
            )
    }
    
    private func errorRow(_ text: String) -> some View {
        HStack(spacing: DS.s6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.orange)
        }
    }
}
