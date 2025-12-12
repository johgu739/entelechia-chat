import SwiftUI
import UIContracts

struct NavigatorFilterField: View {
    let filterText: String
    let onWorkspaceIntent: (UIContracts.WorkspaceIntent) -> Void
    
    var body: some View {
        HStack(spacing: DS.s6) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            TextField("Filter", text: Binding(
                get: { filterText },
                set: { onWorkspaceIntent(.setFilterText($0)) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            
            if !filterText.isEmpty {
                Button {
                    onWorkspaceIntent(.setFilterText(""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.s8)
        .padding(.vertical, DS.s4)
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(DS.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r12)
                        .stroke(DS.stroke, lineWidth: 1)
                )
        )
        .padding(.horizontal, DS.s6)
        .padding(.vertical, DS.s6)
        .background(Color.clear)
    }
}
