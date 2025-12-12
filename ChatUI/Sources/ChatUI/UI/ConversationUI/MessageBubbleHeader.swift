import SwiftUI

struct MessageBubbleHeader: View {
    let isAssistant: Bool
    let createdAt: Date
    
    var body: some View {
        HStack(spacing: DS.s6) {
            Text(isAssistant ? "Assistant" : "You")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Text(createdAt, style: .time)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: isAssistant ? .leading : .trailing)
    }
}
