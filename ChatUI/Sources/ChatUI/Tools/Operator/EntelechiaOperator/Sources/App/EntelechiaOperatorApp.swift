// @EntelechiaHeaderStart
// Signifier: EntelechiaOperatorApp
// Substance: Operator app telos orchestrator
// Genus: Teleological entry point
// Differentia: Assembles operator scenes and services
// Form: Scene setup and dependency provision for operator
// Matter: Operator state objects; windows; environment
// Powers: Launch operator UI; assemble services
// FinalCause: Enable operating on projects with tooling support
// Relations: Governs operator views; depends on subsystem services
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Combine
import SwiftUI

// Note: @main removed - this app shares the module with EntelechiaChatApp
// To use this as the main app, remove @main from EntelechiaChatApp.swift
struct EntelechiaOperatorApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootLayout()
                .environmentObject(appState)
                .frame(minWidth: 1200, minHeight: 800)
        }
    }
}
