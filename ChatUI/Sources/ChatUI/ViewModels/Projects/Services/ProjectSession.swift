// @EntelechiaHeaderStart
// Signifier: ProjectSession
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
import AppCoreEngine
import Combine
import os.log

enum ProjectSessionError: LocalizedError {
    case invalidProjectURL(URL, Error)
    case missingProjectDirectory(String)
    case reloadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidProjectURL(let url, _):
            return "Unable to determine a valid project directory for \(url.path)."
        case .missingProjectDirectory(let path):
            return "Project path does not exist: \(path)"
        case .reloadFailed:
            return "Failed to reload project files."
        }
    }

    var failureReason: String? {
        switch self {
        case .invalidProjectURL(_, let error):
            return error.localizedDescription
        case .missingProjectDirectory(let path):
            return "The directory \(path) was not found on disk."
        case .reloadFailed(let error):
            return error.localizedDescription
        }
    }
}

/// Runtime session for the currently open project
final class ProjectSession: ObservableObject, ProjectSessioning {
    @Published var activeProjectURL: URL?
    @Published var projectName: String = ""
    
    private let projectEngine: ProjectEngine
    private let workspaceEngine: WorkspaceEngine
    private let securityScopeHandler: SecurityScopeHandling
    private var activeSecurityScopedURL: URL?
    private var hasActiveSecurityScope: Bool = false
    private let logger = Logger.persistence
    private var alertCenter: AlertCenter?
    
    init(
        projectEngine: ProjectEngine,
        workspaceEngine: WorkspaceEngine,
        securityScopeHandler: SecurityScopeHandling
    ) {
        self.projectEngine = projectEngine
        self.workspaceEngine = workspaceEngine
        self.securityScopeHandler = securityScopeHandler
    }

    func setAlertCenter(_ center: AlertCenter) {
        alertCenter = center
    }
    
    /// Open a project (runtime state only - persistence handled by ProjectCoordinator)
    func open(_ url: URL, name: String? = nil, bookmarkData: Data? = nil) {
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
            logger.error("Failed to resolve project directory: \(error.localizedDescription, privacy: .public)")
            let wrapped = ProjectSessionError.invalidProjectURL(url, error)
            alertCenter?.publish(wrapped, fallbackTitle: "Unable to Open Project")
            return
        }
        
        // Validate resolved directory exists
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            logger.error("Project path does not exist: \(resolvedURL.path, privacy: .public)")
            let wrapped = ProjectSessionError.missingProjectDirectory(resolvedURL.path)
            alertCenter?.publish(wrapped, fallbackTitle: "Unable to Open Project")
            return
        }
        
        // Close current project if any
        if activeProjectURL != nil {
            close()
        }

        // Start security-scoped access if available
        startSecurityScope(for: resolvedURL, bookmarkData: bookmarkData)
        
        // Set active project (runtime state only)
        let finalName = name ?? resolvedURL.lastPathComponent
        activeProjectURL = resolvedURL
        projectName = finalName
    }
    
    /// Close the current project (runtime state only - persistence handled by ProjectCoordinator)
    func close() {
        stopSecurityScopeIfNeeded()
        activeProjectURL = nil
        projectName = ""
    }
    
    /// Reload engine snapshot for current project (UI projection happens elsewhere)
    func reloadSnapshot() async -> WorkspaceSnapshot {
        guard activeProjectURL != nil else { return .empty }
        do {
            return try await workspaceEngine.refresh()
        } catch {
            logger.error("Failed to reload files: \(error.localizedDescription, privacy: .public)")
            let wrapped = ProjectSessionError.reloadFailed(error)
            alertCenter?.publish(wrapped, fallbackTitle: "Failed to Reload Project")
            return .empty
        }
    }

    private func startSecurityScope(for url: URL, bookmarkData: Data?) {
        var targetURL = url
        if let data = bookmarkData, let resolved = try? securityScopeHandler.resolveBookmark(data) {
            targetURL = resolved
        }
        let started = securityScopeHandler.startAccessing(targetURL)
        if started {
            hasActiveSecurityScope = true
            activeSecurityScopedURL = targetURL
        }
    }

    private func stopSecurityScopeIfNeeded() {
        if hasActiveSecurityScope, let url = activeSecurityScopedURL {
            securityScopeHandler.stopAccessing(url)
        }
        hasActiveSecurityScope = false
        activeSecurityScopedURL = nil
    }
}
