import SwiftUI

struct CodeBlockHeader: View {
    let language: String?
    let copied: Bool
    let onCopy: () -> Void
    
    var body: some View {
        HStack {
            if let language, !language.isEmpty {
                Text(language.uppercased())
                    .font(DS.monoFootnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onCopy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: DS.s20, height: DS.s20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.s12)
        .padding(.vertical, DS.s8)
        .background(DS.stroke.opacity(0.12))
    }
}
