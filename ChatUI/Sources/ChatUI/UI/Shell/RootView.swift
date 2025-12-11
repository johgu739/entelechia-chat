// @EntelechiaHeaderStart
// Signifier: RootView
// Substance: UI shell switcher
// Genus: UI shell view
// Differentia: Routes onboarding vs workspace
// Form: Conditional routing based on session state
// Matter: Environment objects; session state bindings
// Powers: Present appropriate root view
// FinalCause: Direct user to correct UI state
// Relations: Depends on session/store; serves shell
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import UIConnections

/// Root view that switches between onboarding and main workspace
public struct RootView: View {
    public let context: WorkspaceContext
    
    public init(context: WorkspaceContext) {
        self.context = context
    }
    
    public var body: some View {
        Group {
            if context.projectSession.activeProjectURL == nil {
                OnboardingSelectProjectView(
                    coordinator: context.projectCoordinator,
                    alertCenter: context.alertCenter
                )
            } else {
                MainWorkspaceView(context: context)
            }
        }
        .alertPresentation(alertCenter: context.alertCenter)
    }
}
