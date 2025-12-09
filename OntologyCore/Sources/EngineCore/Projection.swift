public struct Projection: Hashable, Sendable {
    public var derivedPropositions: [Proposition]
    public var requiredInvariants: [InvariantID]
    public var scope: Scope
    public var justification: String?

    public init(
        derivedPropositions: [Proposition],
        requiredInvariants: [InvariantID] = [],
        scope: Scope,
        justification: String? = nil
    ) {
        self.derivedPropositions = derivedPropositions
        self.requiredInvariants = requiredInvariants
        self.scope = scope
        self.justification = justification
    }
}

