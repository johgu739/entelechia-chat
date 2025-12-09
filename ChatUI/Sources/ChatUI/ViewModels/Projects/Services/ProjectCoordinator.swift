// @EntelechiaHeaderStart
// Signifier: ProjectCoordinator
// Substance: Project coordination faculty
// Genus: Project domain faculty
// Differentia: Opens/closes projects and updates recents
// Form: Rules for validation, bookmarking, session open/close
// Matter: Project paths; bookmarks; engine updates
// Powers: Validate; bookmark; update engine; open sessions
// FinalCause: Manage lifecycle of projects coherently
// Relations: Governs ProjectSession; depends on ProjectEngine
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import Combine
import os.log
import AppCoreEngine

struct RecentProject: Equatable {
    let representation: ProjectRepresentation
    let bookmarkData: Data?
}

protocol ProjectSessioning: AnyObject {
    func open(_ url: URL, name: String?, bookmarkData: Data?)
    func close()
    func reloadSnapshot() async -> WorkspaceSnapshot
}

/// Coordinator for project operations (menu commands, file selection)
@MainActor
final class ProjectCoordinator: ObservableObject {
    let projectEngine: ProjectEngine
    private let projectSession: ProjectSessioning
    private let alertCenter: AlertCenter
    private let logger = Logger.persistence
    private let securityScopeHandler: SecurityScopeHandling
    private let projectMetadataHandler: ProjectMetadataHandling
    
    init(
        projectEngine: ProjectEngine,
        projectSession: ProjectSessioning,
        alertCenter: AlertCenter,
        securityScopeHandler: SecurityScopeHandling,
        projectMetadataHandler: ProjectMetadataHandling
    ) {
        self.projectEngine = projectEngine
        self.projectSession = projectSession
        self.alertCenter = alertCenter
        self.securityScopeHandler = securityScopeHandler
        self.projectMetadataHandler = projectMetadataHandler
    }
    
    /// Open project with URL and name (called from onboarding view)
    /// Name is REQUIRED - no optionals, no fallbacks
    func openProject(url: URL, name: String) {
        do {
            let rep = try projectEngine.validateProject(at: url)
            let resolvedURL = URL(fileURLWithPath: rep.rootPath)
            let bookmarkData = try securityScopeHandler.createBookmark(for: resolvedURL)
            let stored = projectMetadataHandler.withMetadata(
                projectMetadataHandler.metadata(for: bookmarkData, lastSelection: nil, isLastOpened: true),
                appliedTo: rep
            )
            try projectEngine.save(stored)
            projectSession.open(resolvedURL, name: stored.name, bookmarkData: bookmarkData)
        } catch {
            logger.error("Failed to open project at \(url.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            alertCenter.publish(error, fallbackTitle: "Project Open Failed")
        }
    }
    
    /// Close current project
    func closeProject() {
        projectSession.close()
    }
    
    /// Open a recent project
    func openRecent(_ project: RecentProject) {
        do {
            let rep = project.representation
            let url = URL(fileURLWithPath: rep.rootPath)
            let bookmarkData = project.bookmarkData ?? (try? securityScopeHandler.createBookmark(for: url))
            let stored = projectMetadataHandler.withMetadata(
                projectMetadataHandler.metadata(for: bookmarkData, lastSelection: nil, isLastOpened: true),
                appliedTo: rep
            )
            try projectEngine.save(stored)
            projectSession.open(url, name: rep.name, bookmarkData: bookmarkData)
        } catch {
            logger.error("Failed to open recent project \(project.representation.rootPath, privacy: .private): \(error.localizedDescription, privacy: .public)")
            alertCenter.publish(error, fallbackTitle: "Open Recent Failed")
        }
    }
    
    /// Get recent projects for menu
    var recentProjects: [RecentProject] {
        engineRecentProjects()
    }

    // MARK: - Helpers

    private func persistProject(url: URL, name: String, bookmarkData: Data?) throws {
        let rep = ProjectRepresentation(rootPath: url.path, name: name)
        let stored = projectMetadataHandler.withMetadata(
            projectMetadataHandler.metadata(for: bookmarkData, lastSelection: nil, isLastOpened: true),
            appliedTo: rep
        )
        try projectEngine.save(stored)
    }
    
    private func engineRecentProjects() -> [RecentProject] {
        let reps = (try? projectEngine.loadAll()) ?? []
        return reps.map {
            RecentProject(
                representation: $0,
                bookmarkData: projectMetadataHandler.bookmarkData(from: $0.metadata)
            )
        }
    }
}

