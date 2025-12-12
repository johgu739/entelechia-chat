@MainActor
public protocol ProjectSessioning: AnyObject {
    func open(_ url: URL, name: String?, bookmarkData: Data?)
    func close()
    func reloadSnapshot() async -> WorkspaceSnapshot
}
import Foundation
import os.log
import Combine
import AppCoreEngine

public enum ProjectSessionError: LocalizedError, Sendable {
    case invalidProjectURL(URL, Error)
    case missingProjectDirectory(String)
    case reloadFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidProjectURL(let url, _):
            return "Unable to determine a valid project directory for \(url.path)."
        case .missingProjectDirectory(let path):
            return "Project path does not exist: \(path)"
        case .reloadFailed:
            return "Failed to reload project files."
        }
    }
    
    public var failureReason: String? {
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

/// Runtime session for the currently open project.
@MainActor
public final class ProjectSession: ObservableObject, ProjectSessioning {
    @Published public var activeProjectURL: URL?
    @Published public var projectName: String = ""
    
    private let projectEngine: ProjectEngine
    private let workspaceEngine: WorkspaceEngine
    private let securityScopeHandler: SecurityScopeHandling
    private var activeSecurityScopedURL: URL?
    private var hasActiveSecurityScope: Bool = false
    private let logger = Logger(subsystem: "UIConnections", category: "ProjectSession")
    private let errorAuthority: DomainErrorAuthority
    
    public init(
        projectEngine: ProjectEngine,
        workspaceEngine: WorkspaceEngine,
        securityScopeHandler: SecurityScopeHandling,
        errorAuthority: DomainErrorAuthority
    ) {
        self.projectEngine = projectEngine
        self.workspaceEngine = workspaceEngine
        self.securityScopeHandler = securityScopeHandler
        self.errorAuthority = errorAuthority
    }
    
    public func open(_ url: URL, name: String? = nil, bookmarkData: Data? = nil) {
        let resolvedURL: URL
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            resolvedURL = (resourceValues.isDirectory == true) ? url : url.deletingLastPathComponent()
        } catch {
            logger.error("Failed to resolve project directory: \(error.localizedDescription)")
            let wrapped = ProjectSessionError.invalidProjectURL(url, error)
            errorAuthority.publish(wrapped, context: "Open project")
            return
        }
        
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            logger.error("Project path does not exist: \(resolvedURL.path)")
            let wrapped = ProjectSessionError.missingProjectDirectory(resolvedURL.path)
            errorAuthority.publish(wrapped, context: "Open project")
            return
        }
        
        if activeProjectURL != nil {
            close()
        }
        
        startSecurityScope(for: resolvedURL, bookmarkData: bookmarkData)
        let finalName = name ?? resolvedURL.lastPathComponent
        activeProjectURL = resolvedURL
        projectName = finalName
    }
    
    public func close() {
        stopSecurityScopeIfNeeded()
        activeProjectURL = nil
        projectName = ""
    }
    
    public func reloadSnapshot() async -> WorkspaceSnapshot {
        guard activeProjectURL != nil else { return .empty }
        do {
            return try await workspaceEngine.refresh()
        } catch {
            logger.error("Failed to reload files: \(error.localizedDescription)")
            let wrapped = ProjectSessionError.reloadFailed(error)
            errorAuthority.publish(wrapped, context: "Reload project")
            return .empty
        }
    }
    
    private func startSecurityScope(for url: URL, bookmarkData: Data?) {
        var targetURL = url
        if let data = bookmarkData, let resolved = try? securityScopeHandler.resolveBookmark(data) {
            targetURL = resolved
        }
        if securityScopeHandler.startAccessing(targetURL) {
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

