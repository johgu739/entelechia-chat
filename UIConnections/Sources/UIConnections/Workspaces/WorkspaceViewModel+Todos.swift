import Foundation

extension WorkspaceViewModel {
    func loadProjectTodos(for root: URL?) {
        guard let root else {
            projectTodos = .empty
            todosError = nil
            return
        }
        Task {
            do {
                let todos = try projectTodosLoader.loadTodos(for: root)
                await MainActor.run {
                    projectTodos = todos
                    todosError = nil
                }
            } catch {
                await MainActor.run {
                    projectTodos = .empty
                    todosError = "Failed to load ProjectTodos.ent.json: \(error.localizedDescription)"
                }
            }
        }
    }
}

