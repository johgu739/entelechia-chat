// @EntelechiaHeaderStart
// Substance: Operator app state container
// Genus: Application faculty
// Differentia: Holds observable operator state
// Form: Observable properties and reducers for operator flows
// Matter: State values for navigation; editor; daemon linkage
// Powers: Hold and mutate operator UI/application state
// FinalCause: Coordinate operator interactions and side effects
// Relations: Serves operator views; depends on services for effects
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var selection: NavigatorSelection = .none
    @Published var openTabs: [EditorTab] = []
    @Published var activeTabID: UUID?
    @Published var isInspectorVisible: Bool = true
    @Published var isConsoleVisible: Bool = false

    func toggleInspector() {
        isInspectorVisible.toggle()
    }

    func toggleConsole() {
        isConsoleVisible.toggle()
    }
}