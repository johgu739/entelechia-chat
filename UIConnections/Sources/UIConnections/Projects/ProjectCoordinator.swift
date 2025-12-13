import Foundation
import os.log
import Combine
import AppCoreEngine
import UIContracts

/// Internal coordinator for project operations (menu commands, file selection).
/// Use `createProjectCoordinator` factory function to create instances.
@MainActor
internal final class ProjectCoordinator: ProjectCoordinating {
    internal let projectEngine: ProjectEngine
    private let projectSession: ProjectSessioning
    private let errorAuthority: DomainErrorAuthority
    private let logger = Logger(subsystem: "UIConnections", category: "ProjectCoordinator")
    private let securityScopeHandler: SecurityScopeHandling
    private let projectMetadataHandler: ProjectMetadataHandling
    
    internal init(
        projectEngine: ProjectEngine,
        projectSession: ProjectSessioning,
        errorAuthority: DomainErrorAuthority,
        securityScopeHandler: SecurityScopeHandling,
        projectMetadataHandler: ProjectMetadataHandling
    ) {
        self.projectEngine = projectEngine
        self.projectSession = projectSession
        self.errorAuthority = errorAuthority
        self.securityScopeHandler = securityScopeHandler
        self.projectMetadataHandler = projectMetadataHandler
    }
    
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
            logger.error("Failed to open project at \(url.path): \(error.localizedDescription)")
            errorAuthority.publish(error, context: "Open project")
        }
    }
    
    func closeProject() {
        projectSession.close()
    }
    
    func openRecent(_ project: UIContracts.RecentProject) {
        do {
            // Map UIContracts.UIProjectRepresentation to AppCoreEngine.ProjectRepresentation
            let domainRep = AppCoreEngine.ProjectRepresentation(
                rootPath: project.representation.rootPath,
                name: project.representation.name,
                metadata: project.representation.metadata,
                linkedFiles: project.representation.linkedFiles
            )
            let url = URL(fileURLWithPath: domainRep.rootPath)
            let bookmarkData = project.bookmarkData ?? (try? securityScopeHandler.createBookmark(for: url))
            let stored = projectMetadataHandler.withMetadata(
                projectMetadataHandler.metadata(for: bookmarkData, lastSelection: nil, isLastOpened: true),
                appliedTo: domainRep
            )
            try projectEngine.save(stored)
            projectSession.open(url, name: domainRep.name, bookmarkData: bookmarkData)
        } catch {
            logger.error(
                "Failed to open recent project \(project.representation.rootPath): \(error.localizedDescription)"
            )
            errorAuthority.publish(error, context: "Open recent project")
        }
    }
    
    var recentProjects: [UIContracts.RecentProject] {
        engineRecentProjects()
    }
    
    private func engineRecentProjects() -> [UIContracts.RecentProject] {
        let reps = (try? projectEngine.loadAll()) ?? []
        return reps.map {
            let internalProject = RecentProject(
                representation: $0,
                bookmarkData: projectMetadataHandler.bookmarkData(from: $0.metadata)
            )
            return DomainToUIMappers.toRecentProject(internalProject)
        }
    }
}

// MARK: - Internal RecentProject (for mapping)

internal struct RecentProject: Equatable, Sendable {
    let representation: AppCoreEngine.ProjectRepresentation
    let bookmarkData: Data?
    
    init(representation: AppCoreEngine.ProjectRepresentation, bookmarkData: Data?) {
        self.representation = representation
        self.bookmarkData = bookmarkData
    }
}

// MARK: - Public Protocol

// ProjectCoordinating protocol is defined in Protocols/CoordinatorProtocols.swift
// createProjectCoordinator factory is defined in Factories/CoordinatorFactories.swift

