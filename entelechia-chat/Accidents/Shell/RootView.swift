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

/// Root view that switches between onboarding and main workspace
struct RootView: View {
    let assistant: CodeAssistant
    let workspaceFileSystemService: WorkspaceFileSystemService
    let preferencesStore: PreferencesStore
    let contextPreferencesStore: ContextPreferencesStore
    @EnvironmentObject var projectSession: ProjectSession
    @EnvironmentObject var conversationStore: ConversationStore
    @EnvironmentObject var projectCoordinator: ProjectCoordinator
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var alertCenter: AlertCenter
    @EnvironmentObject var appEnvironment: AppEnvironment
    
    var codexBannerReason: String? {
        if case .mockFallback(let reason) = appEnvironment.configurationStatus {
            return reason
        }
        return nil
    }
    
    var shouldShowCodexBanner: Bool {
        if case .mockFallback = appEnvironment.configurationStatus {
            return true
        }
        return false
    }
    
    // Static helpers for tests to avoid rendering SwiftUI views.
    static func shouldShowCodexBanner(for status: AppEnvironment.ConfigurationStatus) -> Bool {
        if case .mockFallback = status { return true }
        return false
    }
    
    static func codexBannerReason(for status: AppEnvironment.ConfigurationStatus) -> String? {
        if case .mockFallback(let reason) = status { return reason }
        return nil
    }
    
    var body: some View {
        Group {
            // Simple 2-state machine: onboarding / workspace
            if projectSession.activeProjectURL == nil {
                OnboardingSelectProjectView(coordinator: projectCoordinator)
            } else {
                MainWorkspaceView(
                    assistant: assistant,
                    workspaceFileSystemService: workspaceFileSystemService,
                    preferencesStore: preferencesStore,
                    contextPreferencesStore: contextPreferencesStore
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
        .overlay(alignment: .top) {
            if let reason = codexBannerReason {
                codexBanner(reason: reason)
            }
        }
    }
    
    @ViewBuilder
    private func codexBanner(reason: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex not configured")
                    .font(.headline)
                Text(reason)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(12)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
