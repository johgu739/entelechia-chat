// @EntelechiaHeaderStart
// Signifier: ProjectCoordinator
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
import Combine
import os.log

enum ProjectCoordinatorError: LocalizedError {
    case emptyName
    case directoryResolutionFailed(String)
    case missingPath(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Project name is required."
        case .directoryResolutionFailed(let path):
            return "Could not resolve a project directory for \(path)."
        case .missingPath(let path):
            return "Project path does not exist: \(path)."
        }
    }

    var failureReason: String? { errorDescription }
}

protocol ProjectSessioning: AnyObject {
    func open(_ url: URL, name: String?, bookmarkData: Data?)
    func close()
}

/// Coordinator for project operations (menu commands, file selection)
@MainActor
final class ProjectCoordinator: ObservableObject {
    let projectStore: ProjectStore
    private let projectSession: ProjectSessioning
    private let alertCenter: AlertCenter
    private let logger = Logger.persistence
    private let securityScopeHandler: SecurityScopeHandling
    
    init(
        projectStore: ProjectStore,
        projectSession: ProjectSessioning,
        alertCenter: AlertCenter,
        securityScopeHandler: SecurityScopeHandling
    ) {
        self.projectStore = projectStore
        self.projectSession = projectSession
        self.alertCenter = alertCenter
        self.securityScopeHandler = securityScopeHandler
        
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
        do {
            let trimmedName = try validatedName(name)
            let resolvedURL = try resolveDirectory(for: url)
            let bookmarkData = try securityScopeHandler.makeBookmark(for: resolvedURL)
            try persistProject(url: resolvedURL, name: trimmedName, bookmarkData: bookmarkData)
            projectSession.open(resolvedURL, name: trimmedName, bookmarkData: bookmarkData)
        } catch {
            logger.error("Failed to open project at \(url.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            alertCenter.publish(error, fallbackTitle: "Project Open Failed")
        }
    }
    
    /// Close current project
    func closeProject() {
        do {
            try projectStore.setLastOpened(url: nil)
        } catch {
            logger.error("Failed to close project: \(error.localizedDescription, privacy: .public)")
            alertCenter.publish(error, fallbackTitle: "Close Project Failed")
            return
        }
        projectSession.close()
    }
    
    /// Open a recent project
    func openRecent(_ project: ProjectStore.StoredProject) {
        do {
            let trimmedName = try validatedName(project.name)
            guard let resolved = projectStore.resolvedProjectURL(project) else {
                throw ProjectCoordinatorError.missingPath(project.path)
            }

            var bookmarkData = resolved.bookmarkData
            if bookmarkData == nil {
                bookmarkData = try securityScopeHandler.makeBookmark(for: resolved.url)
            }

            try projectStore.addRecent(url: resolved.url, name: trimmedName, bookmarkData: bookmarkData)
            try projectStore.setLastOpened(url: resolved.url, name: trimmedName, bookmarkData: bookmarkData)
            projectSession.open(resolved.url, name: trimmedName, bookmarkData: bookmarkData)
        } catch {
            logger.error("Failed to open recent project \(project.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            alertCenter.publish(error, fallbackTitle: "Open Recent Failed")
        }
    }
    
    /// Get recent projects for menu
    var recentProjects: [ProjectStore.StoredProject] {
        projectStore.recentProjects
    }

    // MARK: - Helpers

    private func validatedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectCoordinatorError.emptyName
        }
        return trimmed
    }

    private func resolveDirectory(for url: URL) throws -> URL {
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            let directoryURL = values.isDirectory == true ? url : url.deletingLastPathComponent()
            guard FileManager.default.fileExists(atPath: directoryURL.path) else {
                throw ProjectCoordinatorError.missingPath(directoryURL.path)
            }
            return directoryURL
        } catch let error as ProjectCoordinatorError {
            throw error
        } catch {
            throw ProjectCoordinatorError.directoryResolutionFailed(url.path)
        }
    }

    private func persistProject(url: URL, name: String, bookmarkData: Data?) throws {
        try projectStore.addRecent(url: url, name: name, bookmarkData: bookmarkData)
        try projectStore.setLastOpened(url: url, name: name, bookmarkData: bookmarkData)
    }
}

// MARK: - Pure helpers for tests (no SwiftUI / security scope)
struct ProjectCoordinatorLogic {
    static func openRecentProject(at path: String, store: ProjectStore) -> Result<Void, ProjectCoordinatorError> {
        do {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .failure(.missingPath(path))
            }
            let trimmedName = store.getName(for: url) ?? url.lastPathComponent
            try store.addRecent(url: url, name: trimmedName, bookmarkData: nil)
            try store.setLastOpened(url: url, name: trimmedName, bookmarkData: nil)
            return .success(())
        } catch let error as ProjectCoordinatorError {
            return .failure(error)
        } catch {
            return .failure(.directoryResolutionFailed(path))
        }
    }
}

extension ProjectCoordinator {
    /// Pure helper to update recents without invoking UI/session side effects.
    /// Avoids security-scoped bookmark creation for headless test environments.
    func openRecentProject(at path: String) -> Result<Void, ProjectCoordinatorError> {
        ProjectCoordinatorLogic.openRecentProject(at: path, store: projectStore)
    }
}
