public enum RelationKind: Sendable {
    case causal
    case dependency
    case refinement
    case contradiction
    case support
}

public struct Relation: Hashable, Sendable {
    public var from: PropositionID
    public var to: PropositionID
    public var kind: RelationKind
    public var scope: Scope
    public var strength: Double?
    public var justification: String?
    public var provenance: Provenance?

    public init(
        from: PropositionID,
        to: PropositionID,
        kind: RelationKind,
        scope: Scope,
        strength: Double? = nil,
        justification: String? = nil,
        provenance: Provenance? = nil
    ) {
        self.from = from
        self.to = to
        self.kind = kind
        self.scope = scope
        self.strength = strength
        self.justification = justification
        self.provenance = provenance
    }
}

