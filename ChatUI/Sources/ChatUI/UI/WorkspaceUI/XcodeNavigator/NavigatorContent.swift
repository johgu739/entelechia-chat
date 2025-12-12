import SwiftUI
import UIContracts

struct NavigatorContent: View {
    let activeNavigator: UIContracts.NavigatorMode
    let workspaceState: UIContracts.WorkspaceUIViewState
    let presentationState: UIContracts.PresentationViewState
    let onWorkspaceIntent: (UIContracts.WorkspaceIntent) -> Void
    
    var body: some View {
        switch activeNavigator {
        case .project:
            XcodeNavigatorRepresentable(
                workspaceState: workspaceState,
                presentationState: presentationState,
                onWorkspaceIntent: onWorkspaceIntent
            )
        case .todos:
            OntologyTodosView(
                projectTodos: workspaceState.projectTodos,
                todosError: workspaceState.todosErrorDescription
            )
        default:
            PlaceholderNavigator()
        }
    }
}
