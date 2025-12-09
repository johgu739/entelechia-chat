import Foundation
import AppCoreEngine
import os

/// Disk-backed loader for `ProjectTodos.ent.json`.
public final class ProjectTodosLoaderAdapter: ProjectTodosLoading, Sendable {
    private let queue = DispatchQueue(label: "ProjectTodosLoaderAdapter.queue")
    private let fileName = "ProjectTodos.ent.json"

    public init() {}

    public func loadTodos(for root: URL) throws -> ProjectTodos {
        try queue.sync {
            let todosURL = root.appendingPathComponent(fileName)
            let fm = FileManager.default
            guard fm.fileExists(atPath: todosURL.path) else {
                return .empty
            }
            let data = try Data(contentsOf: todosURL)
            let decoder = JSONDecoder()
            return try decoder.decode(ProjectTodos.self, from: data)
        }
    }
}

