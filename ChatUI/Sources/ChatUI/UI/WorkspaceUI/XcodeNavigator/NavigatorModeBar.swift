import SwiftUI
import UIConnections

struct NavigatorModeBar: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        HStack(spacing: DS.s4) {
            ForEach(NavigatorMode.allCases, id: \.self) { mode in
                NavigatorModeButton(mode: mode)
                    .environmentObject(workspaceViewModel)
            }
            Spacer()
        }
        .padding(.horizontal, DS.s6)
        .padding(.vertical, DS.s4)
        .background(Color.clear)
    }
}
