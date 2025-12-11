import SwiftUI

struct StreamingChipView: View {
    let text: String
    
    var body: some View {
        HStack(spacing: DS.s8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                .scaleEffect(0.7)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, DS.s12)
        .padding(.vertical, DS.s8)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }
}
