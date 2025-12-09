import Foundation
import AppCoreEngine
import os
@preconcurrency import os.log

/// Adapter that wraps the existing ProjectStore to conform to ProjectPersistenceDriver with ProjectRepresentation.
///
/// Concurrency: access serialized through `lock`; underlying FileManager IO is synchronous. Marked
/// `@unchecked Sendable` because the stored lock and FileManager-bound shim are not statically Sendable.
public final class ProjectStoreRealAdapter: ProjectPersistenceDriver, @unchecked Sendable {
    public typealias StoredProject = [ProjectRepresentation]

    private let store: ProjectStoreShim
    private let lock = OSAllocatedUnfairLock()

    public init(baseURL: URL? = nil) {
        self.store = ProjectStoreShim(baseURL: baseURL)
    }

    public func loadProjects() throws -> [ProjectRepresentation] {
        try lock.withLock {
            let state = try store.loadState()
            var reps: [ProjectRepresentation] = []

            if let last = state.lastOpened {
                reps.append(ProjectRepresentation(
                    rootPath: last.path,
                    name: last.name,
                    metadata: metadata(
                        from: last,
                        lastSelection: state.lastSelections[last.path],
                        lastSelectionDescriptorID: state.lastSelectionDescriptorIDs?[last.path],
                        isLastOpened: true
                    ),
                    linkedFiles: []
                ))
            }

            for entry in state.recent {
                // Avoid duplicate of lastOpened
                if reps.contains(where: { $0.rootPath == entry.path }) { continue }
                reps.append(ProjectRepresentation(
                    rootPath: entry.path,
                    name: entry.name,
                    metadata: metadata(
                        from: entry,
                        lastSelection: state.lastSelections[entry.path],
                        lastSelectionDescriptorID: state.lastSelectionDescriptorIDs?[entry.path],
                        isLastOpened: false
                    ),
                    linkedFiles: []
                ))
            }

            return reps
        }
    }

    public func saveProjects(_ projects: [ProjectRepresentation]) throws {
        try lock.withLock {
            // recents are in array order; lastOpened is the first marked.
            var recents: [ProjectStoreShim.StoredProject] = []
            var lastOpened: ProjectStoreShim.StoredProject?
            var lastSelections: [String: String] = [:]
            var lastSelectionDescriptorIDs: [String: UUID] = [:]

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
                if let selIDString = rep.metadata["lastSelectionDescriptorID"], let uuid = UUID(uuidString: selIDString) {
                    lastSelectionDescriptorIDs[rep.rootPath] = uuid
                }
                recents.append(stored)
            }

            let state = ProjectStoreShim.ProjectData(
                lastOpened: lastOpened,
                recent: recents,
                lastSelections: lastSelections,
                lastSelectionDescriptorIDs: lastSelectionDescriptorIDs.isEmpty ? nil : lastSelectionDescriptorIDs
            )
            try store.saveState(state)
        }
    }

    private func metadata(from stored: ProjectStoreShim.StoredProject, lastSelection: String?, lastSelectionDescriptorID: UUID?, isLastOpened: Bool) -> [String: String] {
        var meta: [String: String] = [:]
        if let data = stored.bookmarkData {
            meta["bookmarkData"] = data.base64EncodedString()
        }
        if let sel = lastSelection {
            meta["lastSelection"] = sel
        }
        if let selID = lastSelectionDescriptorID ?? store.loadStateSafely().lastSelectionDescriptorIDs?[stored.path] {
            meta["lastSelectionDescriptorID"] = selID.uuidString
        }
        if isLastOpened {
            meta["lastOpened"] = "true"
        }
        return meta
    }
}

// MARK: - Shim over existing ProjectStore logic with recents/lastOpened/settings

final class ProjectStoreShim: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock()
    struct StoredProject: Codable, Sendable, Equatable {
        var name: String
        var path: String
        var bookmarkData: Data?
    }

    struct ProjectData: Codable, Sendable {
        var lastOpened: StoredProject?
        var recent: [StoredProject]
        var lastSelections: [String: String]
        var lastSelectionDescriptorIDs: [String: UUID]?
    }

    private let logger = Logger(subsystem: "chat.entelechia.uiconnections", category: "ProjectStoreAdapter")
    private let directory: URL

    init(baseURL: URL? = nil) {
        if let baseURL {
            self.directory = baseURL
        } else if let override = ProcessInfo.processInfo.environment["ENTELECHIA_APP_SUPPORT"] {
            self.directory = URL(fileURLWithPath: override, isDirectory: true)
                .appendingPathComponent("Entelechia", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true)
        } else {
            let fm = FileManager.default
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directory = appSupport
                .appendingPathComponent("Entelechia", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true)
        }
    }

    func loadState() throws -> ProjectData {
        try lock.withLock {
            let fm = FileManager.default
            let url = dataURL()
            guard fm.fileExists(atPath: url.path) else {
                return ProjectData(lastOpened: nil, recent: [], lastSelections: [:], lastSelectionDescriptorIDs: [:])
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ProjectData.self, from: data)
        }
    }

    func loadStateSafely() -> ProjectData {
        (try? loadState()) ?? ProjectData(lastOpened: nil, recent: [], lastSelections: [:], lastSelectionDescriptorIDs: [:])
    }

    func saveState(_ state: ProjectData) throws {
        try lock.withLock {
            let fm = FileManager.default
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = dataURL()
            let data = try JSONEncoder().encode(state)
            try data.write(to: url, options: .atomic)
            logger.debug("Saved projects at \(url.path, privacy: .private)")
        }
    }

    private func dataURL() -> URL {
        directory.appendingPathComponent("projects.json", isDirectory: false)
    }
}

