import SwiftUI
import UIContracts

struct ContextInspectorTabs: View {
    @Binding var selectedInspectorTab: UIContracts.InspectorTab
    
    var body: some View {
        HStack {
            ForEach(UIContracts.InspectorTab.allCases, id: \.self) { tab in
                Button(
                    action: { selectedInspectorTab = tab },
                    label: {
                        Text(title(for: tab))
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
    
    private func title(for tab: UIContracts.InspectorTab) -> String {
        switch tab {
        case .files: return "Files"
        case .quickHelp: return "Quick Help"
        case .context: return "Context"
        }
    }
}

