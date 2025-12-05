// @EntelechiaHeaderStart
// Substance: Project coordination faculty
// Genus: Project domain faculty
// Differentia: Opens/closes projects and updates recents
// Form: Rules for validation, bookmarking, session open/close
// Matter: Project paths; bookmarks; store updates
// Powers: Validate; bookmark; update store; open sessions
// FinalCause: Manage lifecycle of projects coherently
// Relations: Governs ProjectSession; depends on ProjectStore
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import AppKit
import SwiftUI
import Combine

/// Coordinator for project operations (menu commands, file selection)
@MainActor
final class ProjectCoordinator: ObservableObject {
    let projectStore: ProjectStore
    private let projectSession: ProjectSession
    /// Helper to build security-scoped bookmarks with explicit access lifecycle.
    private func makeBookmark(for url: URL) throws -> Data {
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
    
    init(
        projectStore: ProjectStore,
        projectSession: ProjectSession
    ) {
        self.projectStore = projectStore
        self.projectSession = projectSession
        
        // Observe project store changes to update menu
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ProjectStoreDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Already on main queue, safe to access self
            self?.objectWillChange.send()
        }
    }
    
    /// Open project with URL and name (called from onboarding view)
    /// Name is REQUIRED - no optionals, no fallbacks
    func openProject(url: URL, name: String) {
        // Validate name is not empty
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            fatalError("❌ Project name cannot be empty. This is a fatal error - name is required.")
        }
        
        // Resolve URL to directory
        let resolvedURL: URL
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            resolvedURL = resourceValues.isDirectory == true ? url : url.deletingLastPathComponent()
        } catch {
            fatalError("❌ Failed to resolve project directory for \(url.path): \(error.localizedDescription). This is a fatal error.")
        }

        // Persist security-scoped access so we can reopen the project later
        let bookmarkData: Data
        do {
            bookmarkData = try makeBookmark(for: resolvedURL)
        } catch {
            fatalError("❌ Failed to create security-scoped bookmark for \(resolvedURL.path): \(error.localizedDescription). This is a fatal error.")
        }
        
        // Validate directory exists
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            fatalError("❌ Project path does not exist: \(resolvedURL.path). This is a fatal error.")
        }
        
        // Save to store - if this fails, crash with clear error
        do {
            try projectStore.addRecent(url: resolvedURL, name: trimmedName, bookmarkData: bookmarkData)
            try projectStore.setLastOpened(url: resolvedURL, name: trimmedName, bookmarkData: bookmarkData)
        } catch {
            fatalError("❌ Failed to save project to database: \(error.localizedDescription). This is a fatal error - database must be valid.")
        }
        
        // Open session
        projectSession.open(resolvedURL, name: trimmedName, bookmarkData: bookmarkData)
    }
    
    /// Close current project
    func closeProject() {
        // If save fails, crash - no silent errors
        do {
            try projectStore.setLastOpened(url: nil)
        } catch {
            fatalError("❌ Failed to save project state: \(error.localizedDescription). This is a fatal error - database must be valid.")
        }
        projectSession.close()
    }
    
    /// Open a recent project
    func openRecent(_ project: ProjectStore.StoredProject) {
        // Validate name is not empty
        guard !project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fatalError("❌ Project name cannot be empty for project at \(project.path). This is a fatal error - name is required.")
        }

        guard let resolved = projectStore.resolvedProjectURL(project) else {
            fatalError("❌ Project path does not exist or bookmark is invalid: \(project.path). This is a fatal error.")
        }

        var bookmarkData = resolved.bookmarkData
        if bookmarkData == nil {
            do {
                bookmarkData = try makeBookmark(for: resolved.url)
            } catch {
                fatalError("❌ Failed to create security-scoped bookmark for \(resolved.url.path): \(error.localizedDescription). This is a fatal error.")
            }
        }
        
        // Save to store - if this fails, crash with clear error
        do {
            try projectStore.addRecent(url: resolved.url, name: project.name, bookmarkData: bookmarkData)
            try projectStore.setLastOpened(url: resolved.url, name: project.name, bookmarkData: bookmarkData)
        } catch {
            fatalError("❌ Failed to save project to database: \(error.localizedDescription). This is a fatal error - database must be valid.")
        }
        
        projectSession.open(resolved.url, name: project.name, bookmarkData: bookmarkData)
    }
    
    /// Get recent projects for menu
    var recentProjects: [ProjectStore.StoredProject] {
        projectStore.recentProjects
    }
}