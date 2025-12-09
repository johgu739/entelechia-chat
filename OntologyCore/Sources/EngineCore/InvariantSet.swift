public struct InvariantSet: Hashable, Sendable {
    public var invariants: [Invariant]
    public var scope: Scope

    public init(invariants: [Invariant] = [], scope: Scope) {
        self.invariants = invariants
        self.scope = scope
    }
}

