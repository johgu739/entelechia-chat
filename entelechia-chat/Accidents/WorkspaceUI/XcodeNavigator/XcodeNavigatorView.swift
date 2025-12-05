// @EntelechiaHeaderStart
// Substance: Navigator container UI
// Genus: UI container
// Differentia: Hosts mode bar and outline bridge
// Form: Stack of mode bar and outline
// Matter: Workspace VM state bindings
// Powers: Present navigator modes and outline view
// FinalCause: Mirror Xcode-like navigation
// Relations: Serves workspace UI; depends on representable
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppKit

struct XcodeNavigatorView: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        ZStack {
            // Xcode-like sidebar background (visual effect)
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigator mode tabs (like Xcode)
                NavigatorModeBar()
                    .environmentObject(workspaceViewModel)
                
                // Main navigator content
                NavigatorContent()
                    .environmentObject(workspaceViewModel)
                
                if workspaceViewModel.activeNavigator == .project {
                    Divider()
                    
                    // Filter field at bottom (like Xcode)
                    NavigatorFilterField()
                        .environmentObject(workspaceViewModel)
                }
                
            }
        }
        .background(Color.clear)
    }
}

// MARK: - Navigator Mode Bar

private struct NavigatorModeBar: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(NavigatorMode.allCases, id: \.self) { mode in
                NavigatorModeButton(mode: mode)
                    .environmentObject(workspaceViewModel)
            }
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.clear)
    }
}

private struct NavigatorModeButton: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    let mode: NavigatorMode
    
    var isActive: Bool {
        workspaceViewModel.activeNavigator == mode
    }
    
    var body: some View {
        Button {
            workspaceViewModel.activeNavigator = mode
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 8, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.9))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .help(mode.rawValue)
    }
    
    private var badgeCount: Int {
        guard mode == .todos else { return 0 }
        return workspaceViewModel.projectTodos.totalCount
    }
}

// MARK: - Navigator Content

private struct NavigatorContent: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        switch workspaceViewModel.activeNavigator {
        case .project:
            XcodeNavigatorRepresentable()
                .environmentObject(workspaceViewModel)
        case .todos:
            OntologyTodosView()
                .environmentObject(workspaceViewModel)
        default:
            PlaceholderNavigator()
        }
    }
}

private struct PlaceholderNavigator: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Navigator not implemented yet")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


// MARK: - Filter Field

private struct NavigatorFilterField: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            TextField("Filter", text: $workspaceViewModel.filterText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
            
            if !workspaceViewModel.filterText.isEmpty {
                Button {
                    workspaceViewModel.filterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color.clear)
    }
}
