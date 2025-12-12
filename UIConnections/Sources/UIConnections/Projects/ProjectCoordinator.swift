import Foundation
import os.log
import Combine
import AppCoreEngine

public struct RecentProject: Equatable, Sendable {
    public let representation: ProjectRepresentation
    public let bookmarkData: Data?
    
    public init(representation: ProjectRepresentation, bookmarkData: Data?) {
        self.representation = representation
        self.bookmarkData = bookmarkData
    }
}

/// Coordinator for project operations (menu commands, file selection).
@MainActor
public final class ProjectCoordinator: ObservableObject {
    public let projectEngine: ProjectEngine
    private let projectSession: ProjectSessioning
    private let errorAuthority: DomainErrorAuthority
    private let logger = Logger(subsystem: "UIConnections", category: "ProjectCoordinator")
    private let securityScopeHandler: SecurityScopeHandling
    private let projectMetadataHandler: ProjectMetadataHandling
    
    public init(
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
    
    public func openProject(url: URL, name: String) {
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
    
    public func closeProject() {
        projectSession.close()
    }
    
    public func openRecent(_ project: RecentProject) {
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
            logger.error(
                "Failed to open recent project \(project.representation.rootPath): " +
                "\(error.localizedDescription)"
            )
            errorAuthority.publish(error, context: "Open recent project")
        }
    }
    
    public var recentProjects: [RecentProject] {
        engineRecentProjects()
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

