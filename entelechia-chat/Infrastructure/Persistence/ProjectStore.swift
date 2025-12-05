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

/// Persistent storage for project metadata (recent projects, last opened)
final class ProjectStore: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    
    private let maxRecentProjects = 20
    private let storeURL: URL
    
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
    
    private init(data: ProjectData, storeURL: URL) {
        self.data = data
        self.storeURL = storeURL
    }
    
    /// Ensure storage directory exists
    static func ensureStorageDirectory() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let entelechiaDir = appSupport.appendingPathComponent("EntelechiaOperator", isDirectory: true)
        try FileManager.default.createDirectory(at: entelechiaDir, withIntermediateDirectories: true)
    }
    
    /// Load ProjectStore from disk (call this in App.init)
    /// Throws if database file exists but is corrupted or has wrong format
    static func loadFromDisk() throws -> ProjectStore {
        try ensureStorageDirectory()
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let entelechiaDir = appSupport.appendingPathComponent("EntelechiaOperator", isDirectory: true)
        let storeURL = entelechiaDir.appendingPathComponent("projects.json", isDirectory: false)
        
        let data: ProjectData
        if FileManager.default.fileExists(atPath: storeURL.path) {
            // File exists - MUST decode correctly, no fallbacks
            do {
                let fileData = try Data(contentsOf: storeURL)
                data = try JSONDecoder().decode(ProjectData.self, from: fileData)
            } catch {
                // Database file exists but is corrupted - FAIL LOUDLY
                fatalError("❌ ProjectStore database file exists but is corrupted or has wrong format at \(storeURL.path). Error: \(error.localizedDescription). Delete the file manually if you want to start fresh.")
            }
        } else {
            // File doesn't exist - start with empty data
            data = ProjectData()
        }

        let store = ProjectStore(data: data, storeURL: storeURL)

        // Sanitize legacy entries (missing/invalid bookmarks or paths)
        let didChange = store.sanitizeProjectsInPlace()
        if didChange {
            try store.save()
        }

        return store
    }
    
    /// Save data to disk
    /// Throws if save fails - no silent errors
    private func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self.data)
        try data.write(to: storeURL, options: .atomic)
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
        
        try save()
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
        
        try save()
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
        try save()
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
        try save()
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
        
        try save()
        objectWillChange.send()
        
        // Notify menu to update
        NotificationCenter.default.post(name: NSNotification.Name("ProjectStoreDidChange"), object: nil)
    }
    
    /// Clear all recent projects
    /// Throws if save fails
    func clearRecentProjects() throws {
        data.recent.removeAll()
        try save()
        objectWillChange.send()
        
        // Notify menu to update
        NotificationCenter.default.post(name: NSNotification.Name("ProjectStoreDidChange"), object: nil)
    }
}