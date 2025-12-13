// @EntelechiaHeaderStart
// Signifier: XcodeNavigatorView
// Substance: Navigator container UI
// Genus: UI container
// Differentia: Hosts mode bar and outline bridge
// Form: Stack of mode bar and outline
// Matter: Workspace VM state bindings
// Powers: Present navigator modes and outline view
// FinalCause: Mirror Xcode-like navigation
// Relations: Serves workspace UI; depends on representable
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppKit
import UIContracts

struct XcodeNavigatorView: View {
    let workspaceState: UIContracts.WorkspaceUIViewState
    let presentationState: UIContracts.PresentationViewState
    let onWorkspaceIntent: (UIContracts.WorkspaceIntent) -> Void
    
    var body: some View {
        ZStack {
            // Xcode-like sidebar background (visual effect)
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigator mode tabs (like Xcode)
                NavigatorModeBar(
                    activeNavigator: presentationState.activeNavigator,
                    projectTodos: workspaceState.projectTodos,
                    onWorkspaceIntent: onWorkspaceIntent
                )
                .fixedSize(horizontal: false, vertical: true)
                
                // Main navigator content
                NavigatorContent(
                    activeNavigator: presentationState.activeNavigator,
                    workspaceState: workspaceState,
                    presentationState: presentationState,
                    onWorkspaceIntent: onWorkspaceIntent
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if presentationState.activeNavigator == UIContracts.NavigatorMode.project {
                    Divider()
                    
                    // Filter field at bottom (like Xcode)
                    NavigatorFilterField(
                        filterText: presentationState.filterText,
                        onWorkspaceIntent: onWorkspaceIntent
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.clear)
    }
}
