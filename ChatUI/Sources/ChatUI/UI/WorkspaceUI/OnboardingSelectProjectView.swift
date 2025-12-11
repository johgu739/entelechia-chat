// @EntelechiaHeaderStart
// Signifier: OnboardingSelectProjectView
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
import UIConnections

/// Onboarding view shown when no project is open
struct OnboardingSelectProjectView: View {
    @ObservedObject var coordinator: ProjectCoordinator
    let alertCenter: AlertCenter
    @State private var selectedURL: URL?
    @State private var projectName: String = ""
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack(spacing: DS.s16 * CGFloat(2)) {
            Spacer()
            
            // Icon
            Image(systemName: "folder.badge.plus")
                .font(.system(size: DS.s16 * CGFloat(4)))
                .foregroundColor(.secondary)
            
            // Title
            Text("Welcome to Entelechia")
                .font(.system(size: 28, weight: .bold))
            
            // Description
            Text("Select a project folder and name it")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            // Project Name Input (ALWAYS VISIBLE - REQUIRED)
            VStack(alignment: .leading, spacing: DS.s8) {
                Text("Project Name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                TextField("Enter project name", text: $projectName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15))
                    .frame(width: DS.s20 * CGFloat(20))
            }
            .padding(.horizontal, DS.s20 * CGFloat(2))
            
            // Open Project Button
            Button(
                action: { showingFilePicker = true },
                label: {
                    Text("Select Project Folder…")
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, DS.s12 * CGFloat(2))
                        .padding(.vertical, DS.s12)
                }
            )
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
            
            // Show selected folder if any
            if let url = selectedURL {
                VStack(spacing: DS.s4) {
                    Text("Selected:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(url.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: DS.s20 * CGFloat(25))
                    
                    Button(
                        action: { coordinator.openProject(url: url, name: projectName) },
                        label: {
                            Text("Open Project")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, DS.s20)
                                .padding(.vertical, DS.s8)
                        }
                    )
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(.top, 8)
            }
            
            // Recent Projects
            if !coordinator.recentProjects.isEmpty {
                VStack(alignment: .leading, spacing: DS.s16) {
                    Text("Recent Projects")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    ScrollView {
                        VStack(spacing: DS.s8) {
                            ForEach(
                                Array(coordinator.recentProjects.prefix(10)),
                                id: \.representation.rootPath
                            ) { project in
                                RecentProjectRow(project: project) {
                                    coordinator.openRecent(project)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: DS.s20 * CGFloat(15))
                }
                .frame(maxWidth: DS.s20 * CGFloat(25))
                .padding(.top, DS.s20)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.windowBackground)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [],
            allowsMultipleSelection: false,
            onCompletion: { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedURL = url
                        if projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            projectName = url.lastPathComponent
                        }
                    }
                case .failure(let error):
                    alertCenter.publish(error, fallbackTitle: "Folder Selection Failed")
                }
            }
        )
    }
}
