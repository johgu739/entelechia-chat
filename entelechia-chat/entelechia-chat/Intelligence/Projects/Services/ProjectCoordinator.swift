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
import Engine
import UIConnections

struct RecentProject: Equatable {
    let name: String
    let path: String
    let bookmarkData: Data?
}

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
    func reloadDescriptors() async -> [FileDescriptor]
}

/// Coordinator for project operations (menu commands, file selection)
@MainActor
final class ProjectCoordinator: ObservableObject {
    let projectEngine: ProjectEngineImpl<ProjectStoreRealAdapter>
    private let projectSession: ProjectSessioning
    private let alertCenter: AlertCenter
    private let logger = Logger.persistence
    private let securityScopeHandler: SecurityScopeHandling
    
    init(
        projectEngine: ProjectEngineImpl<ProjectStoreRealAdapter>,
        projectSession: ProjectSessioning,
        alertCenter: AlertCenter,
        securityScopeHandler: SecurityScopeHandling
    ) {
        self.projectEngine = projectEngine
        self.projectSession = projectSession
        self.alertCenter = alertCenter
        self.securityScopeHandler = securityScopeHandler
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
        projectSession.close()
    }
    
    /// Open a recent project
    func openRecent(_ project: RecentProject) {
        do {
            let trimmedName = try validatedName(project.name)
            let url = URL(fileURLWithPath: project.path)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ProjectCoordinatorError.missingPath(project.path)
            }
            let bookmarkData = project.bookmarkData ?? (try? securityScopeHandler.makeBookmark(for: url))
            let rep = ProjectRepresentation(
                rootPath: url.path,
                name: trimmedName,
                metadata: metadata(for: bookmarkData, lastSelection: nil, isLastOpened: true)
            )
            try projectEngine.save(rep)
            projectSession.open(url, name: trimmedName, bookmarkData: bookmarkData)
        } catch {
            logger.error("Failed to open recent project \(project.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            alertCenter.publish(error, fallbackTitle: "Open Recent Failed")
        }
    }
    
    /// Get recent projects for menu
    var recentProjects: [RecentProject] {
        engineRecentProjects()
    }

    // MARK: - Helpers

    private func validatedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectCoordinatorError.emptyName
        }
        return trimmed
    }

    private func metadata(for bookmarkData: Data?, lastSelection: String?, isLastOpened: Bool) -> [String: String] {
        var meta: [String: String] = [:]
        if let data = bookmarkData {
            meta["bookmarkData"] = data.base64EncodedString()
        }
        if let sel = lastSelection {
            meta["lastSelection"] = sel
        }
        if isLastOpened {
            meta["lastOpened"] = "true"
        }
        return meta
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
        let rep = ProjectRepresentation(rootPath: url.path, name: name, metadata: metadata(for: bookmarkData, lastSelection: nil, isLastOpened: true))
        try projectEngine.save(rep)
    }
    
    private func engineRecentProjects() -> [RecentProject] {
        guard let reps = try? projectEngine.loadAll(), !reps.isEmpty else { return [] }
        let ordered = reps.sorted { lhs, rhs in
            let lLast = lhs.metadata["lastOpened"] == "true"
            let rLast = rhs.metadata["lastOpened"] == "true"
            if lLast != rLast { return lLast }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return ordered.map { rep in
            RecentProject(
                name: rep.name,
                path: rep.rootPath,
                bookmarkData: rep.metadata["bookmarkData"].flatMap { Data(base64Encoded: $0) }
            )
        }
    }
}

// MARK: - Pure helpers for tests (no SwiftUI / security scope)
struct ProjectCoordinatorLogic {
    static func openRecentProject(at path: String, engine: ProjectEngineImpl<ProjectStoreRealAdapter>) -> Result<Void, ProjectCoordinatorError> {
        do {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .failure(.missingPath(path))
            }
            let trimmedName = url.lastPathComponent
            let rep = ProjectRepresentation(rootPath: url.path, name: trimmedName, metadata: [:])
            try engine.save(rep)
            return .success(())
        } catch let error as ProjectCoordinatorError {
            return .failure(error)
        } catch {
            return .failure(.directoryResolutionFailed(path))
        }
    }
}

