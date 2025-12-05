// @EntelechiaHeaderStart
// Substance: Operator toolbar UI
// Genus: UI control
// Differentia: Toolbar items and actions
// Form: Toolbar item composition and bindings
// Matter: Buttons; commands; bindings
// Powers: Invoke operator commands
// FinalCause: Provide quick access to operator actions
// Relations: Serves operator root layout; depends on app state
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI

struct OperatorToolbar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            ToggleGroup()
            SplitEditorControls()
            Spacer(minLength: 20)
            ConsoleToggle(isOn: $appState.isConsoleVisible)
            DaemonControls()
            SearchField()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

private struct ToggleGroup: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            ToolbarIconButton(systemName: "sidebar.leading", action: toggleNavigator)
            ToolbarIconButton(systemName: "sidebar.trailing", action: appState.toggleInspector)
        }
    }

    private func toggleNavigator() {
        NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
    }
}

private struct ToolbarIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(.plain)
    }
}

private struct SplitEditorControls: View {
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {}) {
                Image(systemName: "square.split.1x2")
            }
            Button(action: {}) {
                Image(systemName: "square.split.2x1")
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DaemonControls: View {
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                Label("Run", systemImage: "play.fill")
            }
            Button(action: {}) {
                Label("Stop", systemImage: "stop.fill")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

private struct ConsoleToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Image(systemName: "rectangle.bottomthird.inset.fill")
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .help("Toggle console (⌥⌘C)")
    }
}

private struct SearchField: View {
    @State private var query: String = ""

    var body: some View {
        TextField("Search", text: $query)
            .textFieldStyle(.roundedBorder)
            .frame(width: 220)
    }
}

struct OperatorConsoleView: View {
    var body: some View {
        Text("Console Output")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}