import SwiftUI
import UIContracts

struct NavigatorModeBar: View {
    let activeNavigator: UIContracts.NavigatorMode
    let projectTodos: UIContracts.ProjectTodos
    let onWorkspaceIntent: (UIContracts.WorkspaceIntent) -> Void
    
    var body: some View {
        HStack(spacing: DS.s4) {
            ForEach(UIContracts.NavigatorMode.allCases, id: \.self) { mode in
                NavigatorModeButton(
                    mode: mode,
                    isActive: activeNavigator == mode,
                    badgeCount: mode == .todos ? projectTodos.totalCount() : 0,
                    onWorkspaceIntent: onWorkspaceIntent
                )
            }
            Spacer()
        }
        .padding(.horizontal, DS.s6)
        .padding(.vertical, DS.s4)
        .background(Color.clear)
    }
}
