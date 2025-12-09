public protocol ConflictReconciling {
    func reconcile(_ conflict: Conflict) -> Resolution
}

