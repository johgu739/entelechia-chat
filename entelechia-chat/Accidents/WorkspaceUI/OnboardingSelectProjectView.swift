// @EntelechiaHeaderStart
// Substance: Onboarding UI
// Genus: UI onboarding view
// Differentia: Collects project folder and name
// Form: Folder picker and naming flow
// Matter: Project URL; name input
// Powers: Collect project selection; open recent
// FinalCause: Admit user into a valid project workspace
// Relations: Serves project coordinator/session
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import UniformTypeIdentifiers

/// Onboarding view shown when no project is open
struct OnboardingSelectProjectView: View {
    @ObservedObject var coordinator: ProjectCoordinator
    @State private var selectedURL: URL?
    @State private var projectName: String = ""
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            // Title
            Text("Welcome to Entelechia")
                .font(.system(size: 28, weight: .bold))
            
            // Description
            Text("Select a project folder and name it")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            // Project Name Input (ALWAYS VISIBLE - REQUIRED)
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                TextField("Enter project name", text: $projectName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15))
                    .frame(width: 400)
            }
            .padding(.horizontal, 40)
            
            // Open Project Button
            Button(action: {
                showingFilePicker = true
            }) {
                Text("Select Project Folder…")
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
            
            // Show selected folder if any
            if let url = selectedURL {
                VStack(spacing: 4) {
                    Text("Selected:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(url.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                    
                    Button(action: {
                        coordinator.openProject(url: url, name: projectName)
                    }) {
                        Text("Open Project")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(.top, 8)
            }
            
            // Recent Projects
            if !coordinator.recentProjects.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Projects")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(coordinator.recentProjects.prefix(10), id: \.path) { project in
                                RecentProjectRow(project: project) {
                                    coordinator.openRecent(project)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
                .frame(maxWidth: 500)
                .padding(.top, 20)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.windowBackground)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedURL = url
                    // Pre-fill name if empty
                    if projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        projectName = url.lastPathComponent
                    }
                }
            case .failure(let error):
                fatalError("❌ Failed to select project folder: \(error.localizedDescription). This is a fatal error.")
            }
        }
    }
}

/// Row for a recent project in the onboarding view
struct RecentProjectRow: View {
    let project: ProjectStore.StoredProject
    let action: () -> Void
    @State private var isHovered = false
    
    private var url: URL {
        URL(fileURLWithPath: project.path)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(url.deletingLastPathComponent().path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
