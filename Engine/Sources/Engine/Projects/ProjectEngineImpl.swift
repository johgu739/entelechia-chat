import Foundation

/// Pure project engine operating on ProjectRepresentation.
public final class ProjectEngineImpl<Persistence: ProjectPersistenceDriver>: ProjectEngine, @unchecked Sendable
where Persistence.StoredProject: Collection, Persistence.StoredProject.Element == ProjectRepresentation {

    private let persistence: Persistence

    public init(persistence: Persistence) {
        self.persistence = persistence
    }

    public func openProject(at url: URL) throws -> ProjectRepresentation {
        let name = url.lastPathComponent
        return ProjectRepresentation(rootPath: url.path, name: name)
    }

    public func save(_ project: ProjectRepresentation) throws {
        var all = try loadAll()
        if let idx = all.firstIndex(where: { $0.rootPath == project.rootPath }) {
            all[idx] = project
        } else {
            all.append(project)
        }
        // Persist back through the driver (requires driver to support Collection storage).
        let boxed = Array(all) as! Persistence.StoredProject
        try persistence.saveProjects(boxed)
    }

    public func loadAll() throws -> [ProjectRepresentation] {
        Array(try persistence.loadProjects())
    }
}

