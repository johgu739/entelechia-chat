import Foundation

/// Single-executor owner for WorkspaceUpdate stream continuation.
actor UpdateStreamBox {
    let stream: AsyncStream<WorkspaceUpdate>
    private var continuation: AsyncStream<WorkspaceUpdate>.Continuation?
    private var finished = false

    init() {
        var cont: AsyncStream<WorkspaceUpdate>.Continuation!
        self.stream = AsyncStream { continuation in
            cont = continuation
        }
        self.continuation = cont
    }

    func yield(_ update: WorkspaceUpdate) {
        guard !finished else { return }
        continuation?.yield(update)
    }

    func finish() {
        guard !finished else { return }
        finished = true
        continuation?.finish()
    }
}

