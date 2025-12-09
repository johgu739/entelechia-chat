import SwiftUI
import AppComposition

/// Public entry point for embedding the Chat UI in a host app (no @main).
public struct ChatUIRoot: View {
    @StateObject private var projectSession: ProjectSession
    @StateObject private var projectCoordinator: ProjectCoordinator
    @StateObject private var alertCenter: AlertCenter
    @StateObject private var codexStatusModel: CodexStatusModel
    private let container: DependencyContainer

    public init() {
        // If running under XCTest, use the test container to avoid side effects.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let testContainer = TestContainer(root: FileManager.default.temporaryDirectory)
            self.container = testContainer
            let alertCenter = testContainer.alertCenter
            _alertCenter = StateObject(wrappedValue: alertCenter)
            _codexStatusModel = StateObject(wrappedValue: CodexStatusModel(availability: testContainer.codexStatus))

            let testSession = ProjectSession(
                projectEngine: testContainer.projectEngine,
                workspaceEngine: testContainer.workspaceEngine,
                securityScopeHandler: testContainer.securityScopeHandler
            )
            _projectSession = StateObject(wrappedValue: testSession)

            _projectCoordinator = StateObject(wrappedValue: ProjectCoordinator(
                projectEngine: testContainer.projectEngine,
                projectSession: testSession,
                alertCenter: alertCenter,
                securityScopeHandler: testContainer.securityScopeHandler,
                projectMetadataHandler: testContainer.projectMetadataHandler
            ))
            return
        }

        let container = DefaultContainer()
        self.container = container
        let alertCenter = container.alertCenter
        _alertCenter = StateObject(wrappedValue: alertCenter)
        _codexStatusModel = StateObject(wrappedValue: CodexStatusModel(availability: container.codexStatus))

        let session = ProjectSession(
            projectEngine: container.projectEngine,
            workspaceEngine: container.workspaceEngine,
            securityScopeHandler: container.securityScopeHandler
        )
        _projectSession = StateObject(wrappedValue: session)

        _projectCoordinator = StateObject(wrappedValue: ProjectCoordinator(
            projectEngine: container.projectEngine,
            projectSession: session,
            alertCenter: alertCenter,
            securityScopeHandler: container.securityScopeHandler,
            projectMetadataHandler: container.projectMetadataHandler
        ))
    }

    public var body: some View {
        RootView(
            workspaceEngine: container.workspaceEngine,
            conversationEngine: container.conversationEngine,
            projectTodosLoader: container.projectTodosLoader
        )
        .environmentObject(projectSession)
        .environmentObject(projectCoordinator)
        .environmentObject(alertCenter)
        .environmentObject(codexStatusModel)
        .frame(minWidth: 1000, minHeight: 700)
    }
}
