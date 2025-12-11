import SwiftUI

struct ContextInspectorTabs: View {
    @Binding var selectedInspectorTab: InspectorTab
    
    var body: some View {
        HStack {
            ForEach(InspectorTab.allCases, id: \.self) { tab in
                Button(
                    action: { selectedInspectorTab = tab },
                    label: {
                        Text(tab.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedInspectorTab == tab ? .primary : .secondary)
                            .padding(.vertical, DS.s8)
                            .padding(.horizontal, DS.s12)
                            .background(
                                RoundedRectangle(cornerRadius: DS.r12)
                                    .fill(selectedInspectorTab == tab ? DS.background : Color.clear)
                            )
                    }
                )
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, DS.s12)
        .padding(.vertical, DS.s8)
    }
}

