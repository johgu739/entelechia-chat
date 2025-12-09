public enum CoherenceStatus: Sendable {
    case coherent
    case incoherent
    case incomplete
    case teleologyDeficient
}

public struct CoherenceReport: Hashable, Sendable {
    public var status: CoherenceStatus
    public var conflicts: [Conflict]
    public var missing: [Prerequisite]
    public var pending: [Projection]
    public var satisfiedInvariants: [InvariantID]
    public var violatedInvariants: [InvariantID]
    public var scope: Scope

    public init(
        status: CoherenceStatus,
        conflicts: [Conflict] = [],
        missing: [Prerequisite] = [],
        pending: [Projection] = [],
        satisfiedInvariants: [InvariantID] = [],
        violatedInvariants: [InvariantID] = [],
        scope: Scope
    ) {
        self.status = status
        self.conflicts = conflicts
        self.missing = missing
        self.pending = pending
        self.satisfiedInvariants = satisfiedInvariants
        self.violatedInvariants = violatedInvariants
        self.scope = scope
    }
}

