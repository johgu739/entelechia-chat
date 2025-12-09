public enum EffectKind: Sendable {
    case accepted
    case rejected
    case revised
    case projected
    case retrodicted
    case reconciled
    case sealed
    case unsealed
}

public struct Delta: Hashable, Sendable {
    public var addedPropositions: [Proposition]
    public var removedPropositions: [PropositionID]
    public var addedRelations: [Relation]
    public var removedRelations: [Relation]
    public var addedInvariants: [Invariant]
    public var removedInvariants: [InvariantID]

    public init(
        addedPropositions: [Proposition] = [],
        removedPropositions: [PropositionID] = [],
        addedRelations: [Relation] = [],
        removedRelations: [Relation] = [],
        addedInvariants: [Invariant] = [],
        removedInvariants: [InvariantID] = []
    ) {
        self.addedPropositions = addedPropositions
        self.removedPropositions = removedPropositions
        self.addedRelations = addedRelations
        self.removedRelations = removedRelations
        self.addedInvariants = addedInvariants
        self.removedInvariants = removedInvariants
    }
}

public struct Effect: Hashable, Sendable {
    public var kind: EffectKind
    public var delta: Delta?
    public var notes: String?

    public init(kind: EffectKind, delta: Delta? = nil, notes: String? = nil) {
        self.kind = kind
        self.delta = delta
        self.notes = notes
    }
}

