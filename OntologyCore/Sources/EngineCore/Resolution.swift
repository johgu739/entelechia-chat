public enum ResolutionAction: Hashable, Sendable {
    case removeProposition(PropositionID)
    case removeRelation(Relation)
    case addProposition(Proposition)
    case addRelation(Relation)
    case overrideInvariant(Invariant)
}

public struct Resolution: Hashable, Sendable {
    public var actions: [ResolutionAction]
    public var residualRisk: String?
    public var satisfiedInvariants: [InvariantID]
    public var scope: Scope
    public var notes: String?

    public init(
        actions: [ResolutionAction],
        residualRisk: String? = nil,
        satisfiedInvariants: [InvariantID] = [],
        scope: Scope,
        notes: String? = nil
    ) {
        self.actions = actions
        self.residualRisk = residualRisk
        self.satisfiedInvariants = satisfiedInvariants
        self.scope = scope
        self.notes = notes
    }
}

