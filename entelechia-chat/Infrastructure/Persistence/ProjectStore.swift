// @EntelechiaHeaderStart
// Signifier: ProjectStore
// Substance: Project metadata store
// Genus: Domain store
// Differentia: Persists recent projects and names
// Form: JSON encode/decode rules
// Matter: StoredProject records; JSON file
// Powers: Load/save recents; last opened; names
// FinalCause: Persist project history and names
// Relations: Serves coordinator/session; depends on FileManager
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation
import Combine
import os.log

enum ProjectStoreError: LocalizedError {
    case applicationSupportUnavailable
    case directoryCreationFailed(Error)
    case databaseCorrupted(URL, Error)
    case saveFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "Unable to access Application Support directory."
        case .directoryCreationFailed(let error):
            return "Failed to create project storage directory: \(error.localizedDescription)"
        case .databaseCorrupted(let url, _):
            return "Project database at \(url.path) is corrupted."
        case .saveFailed(_, let error):
            return "Failed to save project metadata: \(error.localizedDescription)"
        }
    }
}

/// Persistent storage for project metadata (recent projects, last opened)
@MainActor
final class ProjectStore: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    
    private let maxRecentProjects = 20
    private let logger = Logger.persistence
    private let projectsDirectory: ProjectsDirectory
    
    struct StoredProject: Codable, Equatable {
        var name: String
        var path: String
        var bookmarkData: Data?
    }
    
    private struct ProjectData: Codable {
        var lastOpened: StoredProject?
        var recent: [StoredProject]
        var lastSelections: [String: String]
        
        init() {
            self.lastOpened = nil
            self.recent = []
            self.lastSelections = [:]
        }
    }
    
    private var data: ProjectData
    
    private init(data: ProjectData, projectsDirectory: ProjectsDirectory) {
        self.data = data
        self.projectsDirectory = projectsDirectory
        logger.debug("ProjectStore init with \(data.recent.count) recents and lastOpened \(data.lastOpened?.path ?? "nil", privacy: .private)")
    }
    
    deinit {
        let stack = Thread.callStackSymbols.joined(separator: "\n")
        logger.debug("ProjectStore deinit. Stack:\n\(stack, privacy: .public)")
    }
    
    // MARK: - Lifecycle
    
    static func loadFromDisk(
        projectsDirectory provided: ProjectsDirectory? = nil,
        strict: Bool = false
    ) throws -> ProjectStore {
        let projectsDirectory: ProjectsDirectory
        do {
            if let provided = provided {
                projectsDirectory = provided
                try projectsDirectory.ensureExists()
            } else {
                let resolved = try ProjectsDirectory()
                try resolved.ensureExists()
                projectsDirectory = resolved
            }
        } catch {
            Logger.persistence.error("ProjectsDirectory init/ensure failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        let decoder = JSONDecoder()
        let recentURL = projectsDirectory.url(for: .recent)
        let lastOpenedURL = projectsDirectory.url(for: .lastOpened)
        let settingsURL = projectsDirectory.url(for: .settings)
        
        var loaded = ProjectData()
        do {
            if FileManager.default.fileExists(atPath: recentURL.path) {
                let data = try Data(contentsOf: recentURL)
                loaded.recent = try decoder.decode([StoredProject].self, from: data)
                Logger.persistence.debug("Loaded recents from \(recentURL.path, privacy: .private) count=\(loaded.recent.count)")
            } else {
                Logger.persistence.debug("Recents file missing at \(recentURL.path, privacy: .private)")
            }
            
            if FileManager.default.fileExists(atPath: lastOpenedURL.path) {
                let data = try Data(contentsOf: lastOpenedURL)
                loaded.lastOpened = try decoder.decode(StoredProject?.self, from: data)
                Logger.persistence.debug("Loaded lastOpened from \(lastOpenedURL.path, privacy: .private) = \(loaded.lastOpened?.path ?? "nil", privacy: .private)")
            } else {
                Logger.persistence.debug("LastOpened file missing at \(lastOpenedURL.path, privacy: .private)")
            }
            
            if FileManager.default.fileExists(atPath: settingsURL.path) {
                let data = try Data(contentsOf: settingsURL)
                let payload = try decoder.decode(ProjectSettingsPayload.self, from: data)
                loaded.lastSelections = payload.lastSelections
                Logger.persistence.debug("Loaded settings from \(settingsURL.path, privacy: .private) lastSelections=\(payload.lastSelections.count)")
            } else {
                Logger.persistence.debug("Settings file missing at \(settingsURL.path, privacy: .private)")
            }
        } catch {
            Logger.persistence.error("ProjectStore load failed: \(error.localizedDescription, privacy: .public)")
            let stack = Thread.callStackSymbols.joined(separator: "\n")
            Logger.persistence.error("Stack:\n\(stack, privacy: .public)")
            throw error
        }
        
        return ProjectStore(data: loaded, projectsDirectory: projectsDirectory)
    }
    
    static func makeEmptyStore() throws -> ProjectStore {
        let projectsDirectory = try ProjectsDirectory()
        try projectsDirectory.ensureExists()
        return ProjectStore(data: ProjectData(), projectsDirectory: projectsDirectory)
    }
    
    static func inMemoryFallback() -> ProjectStore {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("entelechia-projects-\(UUID().uuidString)", isDirectory: true)
        if let directory = try? ProjectsDirectory(rootURL: tempRoot) {
            return ProjectStore(data: ProjectData(), projectsDirectory: directory)
        }
        // Fallback to default application support if temp setup fails
        let directory = (try? ProjectsDirectory()) ?? (try! ProjectsDirectory())
        return ProjectStore(data: ProjectData(), projectsDirectory: directory)
    }
    
    // MARK: - Save helpers
    
    // Exposed for testing to force flush of all split files.
    func saveAll() throws {
        try saveRecent()
        try saveLastOpened()
        try saveSettings()
    }
    
    private func saveRecent() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self.data.recent)
        let url = projectsDirectory.url(for: .recent)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            logger.info("Saved recent projects to \(url.path, privacy: .private) with \(self.data.recent.count) entries.")
        } catch {
            throw ProjectStoreError.saveFailed(url, error)
        }
    }
    
    private func saveLastOpened() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self.data.lastOpened)
        let url = projectsDirectory.url(for: .lastOpened)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            logger.info("Saved last opened project to \(url.path, privacy: .private).")
        } catch {
            throw ProjectStoreError.saveFailed(url, error)
        }
    }
    
    private func saveSettings() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = ProjectSettingsPayload(lastSelections: data.lastSelections)
        let data = try encoder.encode(payload)
        let url = projectsDirectory.url(for: .settings)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            logger.info("Saved project settings to \(url.path, privacy: .private).")
        } catch {
            throw ProjectStoreError.saveFailed(url, error)
        }
    }
    
    /// Get last opened project URL (validated)
    /// Returns nil if no project is stored or if stored path is invalid
    /// Does NOT silently clear invalid paths - caller must handle
    var lastOpenedProjectURL: URL? {
        guard let stored = data.lastOpened else { return nil }
        guard let resolved = resolvedProjectURL(stored) else { return nil }
        return resolved.url
    }
    
    /// Get recent projects with names (validated)
    var recentProjects: [StoredProject] {
        data.recent.compactMap { stored in resolvedProjectURL(stored).map { _ in stored } }
    }

    /// Access raw stored recents without validation (test-only convenience)
    var storedRecents: [StoredProject] { data.recent }

    /// Access raw last opened without validation (test-only convenience)
    var storedLastOpened: StoredProject? { data.lastOpened }
    
    /// Get project name for a URL (source of truth)
    func getName(for url: URL) -> String? {
        let path = url.path
        
        // Check last opened first
        if let last = data.lastOpened, last.path == path {
            return last.name
        }
        
        // Check recent projects
        if let recent = data.recent.first(where: { $0.path == path }) {
            return recent.name
        }
        
        return nil
    }
    
    /// Set project name (source of truth)
    /// Throws if save fails
    func setName(_ name: String, for url: URL) throws {
        let path = url.path
        
        // Update last opened if it matches
        if data.lastOpened?.path == path {
            data.lastOpened?.name = name
        }
        
        // Update recent if it exists
        if let index = data.recent.firstIndex(where: { $0.path == path }) {
            data.recent[index].name = name
        }
        
        try saveRecent()
        try saveLastOpened()
        logger.info("Updated project name for \(path, privacy: .private) to \(name, privacy: .private).")
        objectWillChange.send()
        NotificationCenter.default.post(name: NSNotification.Name("ProjectStoreDidChange"), object: nil)
    }
    
    /// Add a project to recent list (with optional name)
    /// Throws if save fails
    func addRecent(url: URL, name: String? = nil, bookmarkData: Data? = nil) throws {
        let projectName = name ?? url.lastPathComponent
        let project = StoredProject(name: projectName, path: url.path, bookmarkData: bookmarkData)
        
        // Remove if already exists
        data.recent.removeAll { $0.path == project.path }
        
        // Add to front
        data.recent.insert(project, at: 0)
        
        // Trim to max
        if data.recent.count > maxRecentProjects {
            data.recent = Array(data.recent.prefix(maxRecentProjects))
        }
        
        try saveRecent()
        logger.info("Added recent project \(project.path, privacy: .private).")
        objectWillChange.send()
        
        // Notify menu to update
        NotificationCenter.default.post(name: NSNotification.Name("ProjectStoreDidChange"), object: nil)
    }
    
    /// Set last opened project (with optional name)
    /// Throws if save fails
    func setLastOpened(url: URL?, name: String? = nil, bookmarkData: Data? = nil) throws {
        if let url {
            let projectName = name ?? getName(for: url) ?? url.lastPathComponent
            data.lastOpened = StoredProject(name: projectName, path: url.path, bookmarkData: bookmarkData)
        } else {
            data.lastOpened = nil
        }
        try saveLastOpened()
        logger.info("Set last opened project to \(url?.path ?? "nil", privacy: .private).")
        objectWillChange.send()
        
        // Notify menu to update
        NotificationCenter.default.post(name: NSNotification.Name("ProjectStoreDidChange"), object: nil)
    }
    
    /// Check if project exists in store
    func hasProject(url: URL) -> Bool {
        let path = url.path
        return data.lastOpened?.path == path || data.recent.contains(where: { $0.path == path })
    }

    /// Persist the last selected file/folder for a given project root.
    /// Throws if save fails.
    func setLastSelection(_ selection: URL?, for projectRoot: URL) throws {
        let key = projectRoot.path
        if let selection {
            data.lastSelections[key] = selection.path
        } else {
            data.lastSelections.removeValue(forKey: key)
        }
        try saveSettings()
        logger.info("Persisted last selection for \(projectRoot.path, privacy: .private) to \(selection?.path ?? "nil", privacy: .private).")
        objectWillChange.send()
        NotificationCenter.default.post(name: NSNotification.Name("ProjectStoreDidChange"), object: nil)
    }

    /// Retrieve the last selected file/folder for a project root (validated).
    func lastSelection(for projectRoot: URL) -> URL? {
        let key = projectRoot.path
        guard let path = data.lastSelections[key] else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// Resolve a stored project URL, preferring the security-scoped bookmark if available.
    func resolvedProjectURL(_ stored: StoredProject) -> (url: URL, bookmarkData: Data?)? {
        if let bookmark = stored.bookmarkData {
            var isStale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmark,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                var finalBookmark: Data? = bookmark
                if isStale {
                    finalBookmark = try? resolvedURL.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                }

                return (resolvedURL, finalBookmark)
            } catch {
                print("Error resolving bookmark for \(stored.path): \(error.localizedDescription)")
                return nil
            }
        } else {
            let url = URL(fileURLWithPath: stored.path)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return (url, nil)
        }
    }

    /// Remove or heal invalid stored projects (missing bookmark or missing path).
    /// Returns true if data was modified.
    private func sanitizeProjectsInPlace() -> Bool {
        var changed = false
        func makeBookmark(for url: URL) -> Data? {
            let started = url.startAccessingSecurityScopedResource()
            defer {
                if started {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        }

        // Validate lastOpened
        if let stored = data.lastOpened {
            if let resolved = resolvedProjectURL(stored) {
                if stored.bookmarkData == nil {
                    // Heal missing bookmark if possible
                    if let newBookmark = makeBookmark(for: resolved.url) {
                        data.lastOpened?.bookmarkData = newBookmark
                        changed = true
                    }
                } else if resolved.bookmarkData != stored.bookmarkData, let updated = resolved.bookmarkData {
                    data.lastOpened?.bookmarkData = updated
                    changed = true
                }
            } else {
                data.lastOpened = nil
                changed = true
            }
        }

        // Validate recents
        var newRecent: [StoredProject] = []
        for stored in data.recent {
            if let resolved = resolvedProjectURL(stored) {
                var repaired = stored
                if stored.bookmarkData == nil {
                    if let newBookmark = makeBookmark(for: resolved.url) {
                        repaired.bookmarkData = newBookmark
                        changed = true
                    }
                } else if resolved.bookmarkData != stored.bookmarkData, let updated = resolved.bookmarkData {
                    repaired.bookmarkData = updated
                    changed = true
                }
                newRecent.append(repaired)
            } else {
                changed = true
            }
        }

        if newRecent != data.recent {
            data.recent = newRecent
            changed = true
        }

        // Validate lastSelections (drop entries whose paths no longer exist)
        var newSelections: [String: String] = [:]
        for (projectPath, selectionPath) in data.lastSelections {
            if FileManager.default.fileExists(atPath: projectPath),
               FileManager.default.fileExists(atPath: selectionPath) {
                newSelections[projectPath] = selectionPath
            } else {
                changed = true
            }
        }
        if newSelections != data.lastSelections {
            data.lastSelections = newSelections
            changed = true
        }

        return changed
    }
    
    /// Remove a project from recent list
    /// Throws if save fails
    func removeRecent(url: URL) throws {
        let path = url.path
        data.recent.removeAll { $0.path == path }
        
        // Also clear last opened if it matches
        if data.lastOpened?.path == path {
            data.lastOpened = nil
        }
        
        try saveRecent()
        try saveLastOpened()
        logger.info("Removed recent project \(path, privacy: .private).")
        objectWillChange.send()
        
        // Notify menu to update
        NotificationCenter.default.post(name: NSNotification.Name("ProjectStoreDidChange"), object: nil)
    }
    
    /// Clear all recent projects
    /// Throws if save fails
    func clearRecentProjects() throws {
        data.recent.removeAll()
        try saveRecent()
        logger.info("Cleared all recent projects.")
        objectWillChange.send()
        
        // Notify menu to update
        NotificationCenter.default.post(name: NSNotification.Name("ProjectStoreDidChange"), object: nil)
    }
}

private struct ProjectSettingsPayload: Codable {
    var lastSelections: [String: String]
}
