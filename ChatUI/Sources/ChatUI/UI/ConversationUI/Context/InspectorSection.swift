import SwiftUI

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.s6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundColor(DS.secondaryText)
            
            content
        }
        .padding(.vertical, DS.s8)
    }
}
