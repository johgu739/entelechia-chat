import SwiftUI
import UIConnections

struct NavigatorModeButton: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    let mode: NavigatorMode
    
    private var isActive: Bool {
        workspaceViewModel.activeNavigator == mode
    }
    
    private var badgeCount: Int {
        guard mode == .todos else { return 0 }
        return workspaceViewModel.projectTodos.totalCount
    }
    
    var body: some View {
        Button {
            workspaceViewModel.activeNavigator = mode
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .frame(width: DS.s20, height: DS.s20)
                    .background(
                        RoundedRectangle(cornerRadius: DS.s4)
                            .fill(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 8, weight: .semibold))
                        .padding(.horizontal, DS.s4)
                        .padding(.vertical, DS.s4)
                        .background(Color.accentColor.opacity(0.9))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .offset(x: DS.s8, y: -DS.s8)
                }
            }
        }
        .buttonStyle(.plain)
        .help(mode.rawValue)
    }
}
