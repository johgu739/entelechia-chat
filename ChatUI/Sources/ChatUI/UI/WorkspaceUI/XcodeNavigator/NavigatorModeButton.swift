import SwiftUI
import UIContracts

struct NavigatorModeButton: View {
    let mode: UIContracts.NavigatorMode
    let isActive: Bool
    let badgeCount: Int
    let onWorkspaceIntent: (UIContracts.WorkspaceIntent) -> Void
    
    var body: some View {
        Button {
            onWorkspaceIntent(.setActiveNavigator(mode))
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
