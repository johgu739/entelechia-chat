import Foundation
import CoreEngine
@preconcurrency import os.log

/// Adapter that wraps the existing ProjectStore to conform to ProjectPersistenceDriver with ProjectRepresentation.
public final class ProjectStoreRealAdapter: ProjectPersistenceDriver, @unchecked Sendable {
    public typealias StoredProject = [ProjectRepresentation]

    private let store: ProjectStoreShim

    public init(baseURL: URL? = nil) {
        self.store = ProjectStoreShim(baseURL: baseURL)
    }

    public func loadProjects() throws -> [ProjectRepresentation] {
        let state = try store.loadState()
        var reps: [ProjectRepresentation] = []

        if let last = state.lastOpened {
            reps.append(ProjectRepresentation(
                rootPath: last.path,
                name: last.name,
                metadata: metadata(from: last, lastSelection: state.lastSelections[last.path], isLastOpened: true),
                linkedFiles: []
            ))
        }

        for entry in state.recent {
            // Avoid duplicate of lastOpened
            if reps.contains(where: { $0.rootPath == entry.path }) { continue }
            reps.append(ProjectRepresentation(
                rootPath: entry.path,
                name: entry.name,
                metadata: metadata(from: entry, lastSelection: state.lastSelections[entry.path], isLastOpened: false),
                linkedFiles: []
            ))
        }

        return reps
    }

    public func saveProjects(_ projects: [ProjectRepresentation]) throws {
        // recents are in array order; lastOpened is the first marked.
        var recents: [ProjectStoreShim.StoredProject] = []
        var lastOpened: ProjectStoreShim.StoredProject?
        var lastSelections: [String: String] = [:]

        for rep in projects {
            let stored = ProjectStoreShim.StoredProject(
                name: rep.name,
                path: rep.rootPath,
                bookmarkData: rep.metadata["bookmarkData"].flatMap { Data(base64Encoded: $0) }
            )
            if rep.metadata["lastOpened"] == "true", lastOpened == nil {
                lastOpened = stored
            }
            if let sel = rep.metadata["lastSelection"] {
                lastSelections[rep.rootPath] = sel
            }
            recents.append(stored)
        }

        let state = ProjectStoreShim.ProjectData(
            lastOpened: lastOpened,
            recent: recents,
            lastSelections: lastSelections
        )
        try store.saveState(state)
    }

    private func metadata(from stored: ProjectStoreShim.StoredProject, lastSelection: String?, isLastOpened: Bool) -> [String: String] {
        var meta: [String: String] = [:]
        if let data = stored.bookmarkData {
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
}

// MARK: - Shim over existing ProjectStore logic with recents/lastOpened/settings

final class ProjectStoreShim {
    struct StoredProject: Codable, Sendable, Equatable {
        var name: String
        var path: String
        var bookmarkData: Data?
    }

    struct ProjectData: Codable, Sendable {
        var lastOpened: StoredProject?
        var recent: [StoredProject]
        var lastSelections: [String: String]
    }

    private let logger = Logger(subsystem: "chat.entelechia.uiconnections", category: "ProjectStoreAdapter")
    private let directory: URL
    private let fileManager: FileManager

    init(baseURL: URL? = nil, fileManager: FileManager = .default) {
        if let baseURL {
            self.directory = baseURL
        } else if let override = ProcessInfo.processInfo.environment["ENTELECHIA_APP_SUPPORT"] {
            self.directory = URL(fileURLWithPath: override, isDirectory: true)
                .appendingPathComponent("Entelechia", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true)
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directory = appSupport
                .appendingPathComponent("Entelechia", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true)
        }
        self.fileManager = fileManager
    }

    func loadState() throws -> ProjectData {
        let url = dataURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return ProjectData(lastOpened: nil, recent: [], lastSelections: [:])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ProjectData.self, from: data)
    }

    func saveState(_ state: ProjectData) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = dataURL()
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
        logger.debug("Saved projects at \(url.path, privacy: .private)")
    }

    private func dataURL() -> URL {
        directory.appendingPathComponent("projects.json", isDirectory: false)
    }
}

