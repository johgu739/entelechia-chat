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
import UIConnections

struct XcodeNavigatorView: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        ZStack {
            // Xcode-like sidebar background (visual effect)
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigator mode tabs (like Xcode)
                NavigatorModeBar()
                    .environmentObject(workspaceViewModel)
                
                // Main navigator content
                NavigatorContent()
                    .environmentObject(workspaceViewModel)
                
                if workspaceViewModel.activeNavigator == .project {
                    Divider()
                    
                    // Filter field at bottom (like Xcode)
                    NavigatorFilterField()
                        .environmentObject(workspaceViewModel)
                }
                
            }
        }
        .background(Color.clear)
    }
}
