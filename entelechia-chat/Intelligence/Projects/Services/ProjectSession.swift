// @EntelechiaHeaderStart
// Substance: Project runtime faculty
// Genus: Project domain faculty
// Differentia: Holds active project state
// Form: State for active project, name, reload
// Matter: Active URL; project name
// Powers: Open/close project; reload files
// FinalCause: Hold current project context for the app
// Relations: Serves workspace UI; depends on file system service
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import SwiftUI
import Combine

/// Runtime session for the currently open project
@MainActor
final class ProjectSession: ObservableObject {
    @Published var activeProjectURL: URL?
    @Published var projectName: String = ""
    
    private let projectStore: ProjectStore
    private let fileSystemService: WorkspaceFileSystemService
    private var activeSecurityScopedURL: URL?
    private var hasActiveSecurityScope: Bool = false
    
    init(
        projectStore: ProjectStore,
        fileSystemService: WorkspaceFileSystemService
    ) {
        self.projectStore = projectStore
        self.fileSystemService = fileSystemService
    }
    
    /// Open a project (runtime state only - persistence handled by ProjectCoordinator)
    func open(_ url: URL, name: String? = nil, bookmarkData _: Data? = nil) {
        // Determine a valid project root directory.
        // If the URL is a file (e.g. .xcodeproj), use its parent directory as project root.
        let resolvedURL: URL
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true {
                resolvedURL = url
            } else {
                resolvedURL = url.deletingLastPathComponent()
            }
        } catch {
            print("Error: Could not determine directory state for \(url.path): \(error.localizedDescription)")
            return
        }
        
        // Validate resolved directory exists
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            print("Error: Project path does not exist: \(resolvedURL.path)")
            return
        }
        
        // Close current project if any
        if activeProjectURL != nil {
            close()
        }

        // Start security-scoped access if available
        startSecurityScope(for: resolvedURL)
        
        // Set active project (runtime state only)
        // Get name from store (source of truth) or use provided name or fallback to URL
        let finalName = name ?? projectStore.getName(for: resolvedURL) ?? resolvedURL.lastPathComponent
        activeProjectURL = resolvedURL
        projectName = finalName
    }
    
    /// Close the current project (runtime state only - persistence handled by ProjectCoordinator)
    func close() {
        stopSecurityScopeIfNeeded()
        activeProjectURL = nil
        projectName = ""
    }
    
    /// Reload files for current project
    func reloadFiles() -> FileNode? {
        guard let url = activeProjectURL else { return nil }
        return fileSystemService.buildTree(for: url)
    }

    private func startSecurityScope(for url: URL) {
        let started = url.startAccessingSecurityScopedResource()
        if started {
            hasActiveSecurityScope = true
            activeSecurityScopedURL = url
        }
    }

    private func stopSecurityScopeIfNeeded() {
        if hasActiveSecurityScope, let url = activeSecurityScopedURL {
            url.stopAccessingSecurityScopedResource()
        }
        hasActiveSecurityScope = false
        activeSecurityScopedURL = nil
    }
}