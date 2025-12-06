import Foundation

public final class ProjectEngineStub: ProjectEngine, @unchecked Sendable {
    public init() {}

    public func openProject(at url: URL) throws -> ProjectRepresentation {
        ProjectRepresentation(rootPath: url.path, name: url.lastPathComponent)
    }

    public func save(_ project: ProjectRepresentation) throws {
        // no-op stub
    }

    public func loadAll() throws -> [ProjectRepresentation] {
        []
    }
}

