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
import UIContracts

/// Root view that switches between onboarding and main workspace
public struct RootView: View {
    let hasActiveProject: Bool
    let recentProjects: [UIContracts.RecentProject]
    let alert: AlertPresentationModifier.AlertItem?
    let onOpenProject: (URL, String) -> Void
    let onOpenRecent: (UIContracts.RecentProject) -> Void
    let onDismissAlert: () -> Void
    let workspaceContent: () -> AnyView
    
    public init(
        hasActiveProject: Bool,
        recentProjects: [UIContracts.RecentProject],
        alert: AlertPresentationModifier.AlertItem?,
        onOpenProject: @escaping (URL, String) -> Void,
        onOpenRecent: @escaping (UIContracts.RecentProject) -> Void,
        onDismissAlert: @escaping () -> Void,
        workspaceContent: @escaping () -> AnyView
    ) {
        self.hasActiveProject = hasActiveProject
        self.recentProjects = recentProjects
        self.alert = alert
        self.onOpenProject = onOpenProject
        self.onOpenRecent = onOpenRecent
        self.onDismissAlert = onDismissAlert
        self.workspaceContent = workspaceContent
    }
    
    public var body: some View {
        Group {
            if hasActiveProject {
                workspaceContent()
            } else {
                OnboardingSelectProjectView(
                    recentProjects: recentProjects,
                    alert: alert,
                    onOpenProject: onOpenProject,
                    onOpenRecent: onOpenRecent,
                    onDismissAlert: onDismissAlert
                )
            }
        }
        .alertPresentation(alert: alert, onDismiss: onDismissAlert)
    }
}
