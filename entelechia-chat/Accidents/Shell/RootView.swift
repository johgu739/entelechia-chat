// @EntelechiaHeaderStart
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

/// Root view that switches between onboarding and main workspace
struct RootView: View {
    @EnvironmentObject var projectSession: ProjectSession
    @EnvironmentObject var conversationStore: ConversationStore
    @EnvironmentObject var projectCoordinator: ProjectCoordinator
    @EnvironmentObject var store: ProjectStore
    
    var body: some View {
        Group {
            // Simple 2-state machine: onboarding / workspace
            if projectSession.activeProjectURL == nil {
                OnboardingSelectProjectView(coordinator: projectCoordinator)
            } else {
                MainWorkspaceView()
            }
        }
    }
}
