import SwiftUI

struct PropertyRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.s8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            
            content
                .font(.system(size: 13))
            
            Spacer()
        }
        .padding(.vertical, DS.s4)
    }
}
