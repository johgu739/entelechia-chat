import Foundation

public final class ProjectEngineStub: ProjectEngine, Sendable {
    public init() {}

    public func openProject(at url: URL) throws -> ProjectRepresentation {
        try validateProject(at: url)
    }

    public func save(_ project: ProjectRepresentation) throws {
        // no-op stub
    }

    public func loadAll() throws -> [ProjectRepresentation] {
        []
    }

    public func validateProject(at url: URL) throws -> ProjectRepresentation {
        let name = url.lastPathComponent
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EngineError.invalidWorkspace("Project name is required.")
        }
        return ProjectRepresentation(rootPath: url.path, name: name)
    }
}

