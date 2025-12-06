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
import CoreEngine
import AppAdapters

/// Root view that switches between onboarding and main workspace
struct RootView: View {
    let workspaceEngine: WorkspaceEngine
    let conversationEngine: ConversationEngineLive<AnyCodexClient, FileStoreConversationPersistence>
    @EnvironmentObject var projectSession: ProjectSession
    @EnvironmentObject var projectCoordinator: ProjectCoordinator
    @EnvironmentObject var alertCenter: AlertCenter
    
    var body: some View {
        Group {
            // Simple 2-state machine: onboarding / workspace
            if projectSession.activeProjectURL == nil {
                OnboardingSelectProjectView(coordinator: projectCoordinator)
            } else {
                MainWorkspaceView(
                    workspaceEngine: workspaceEngine,
                    conversationEngine: conversationEngine
                )
            }
        }
        .alert(item: $alertCenter.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message + (alert.recoverySuggestion.map { "\n\n\($0)" } ?? "")),
                dismissButton: .default(Text("OK"), action: { alertCenter.alert = nil })
            )
        }
    }
}
