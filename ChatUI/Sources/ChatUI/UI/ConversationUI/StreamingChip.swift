import SwiftUI

struct StreamingChip: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                .scaleEffect(0.7)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

