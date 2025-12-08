// @EntelechiaHeaderStart
// Signifier: RootLayout
// Substance: Operator root layout
// Genus: UI container
// Differentia: Composes sidebar, editor surface, inspectors
// Form: Layout composition of main regions
// Matter: Operator app state bindings; layout containers
// Powers: Arrange main UI regions
// FinalCause: Provide coherent workspace for operator tasks
// Relations: Serves operator shell; depends on navigator/editor components
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import CoreEngine

struct RootLayout: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            OperatorToolbar()
                .environmentObject(appState)

            Divider()

            HSplitView {
                NavigatorSidebar()
                    .frame(minWidth: 220, idealWidth: 250, maxWidth: 280)

                EditorSurface()

                if appState.isInspectorVisible {
                    InspectorPanel()
                        .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)
                }
            }

            if appState.isConsoleVisible {
                Divider()
                OperatorConsoleView()
                    .frame(height: 200)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}