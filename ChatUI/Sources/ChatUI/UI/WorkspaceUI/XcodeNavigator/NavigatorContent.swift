import SwiftUI
import UIConnections

struct NavigatorContent: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        switch workspaceViewModel.activeNavigator {
        case .project:
            XcodeNavigatorRepresentable()
                .environmentObject(workspaceViewModel)
        case .todos:
            OntologyTodosView()
                .environmentObject(workspaceViewModel)
        default:
            PlaceholderNavigator()
        }
    }
}
