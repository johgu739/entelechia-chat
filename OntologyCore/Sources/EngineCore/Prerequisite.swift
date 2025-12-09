public struct Prerequisite: Hashable, Sendable {
    public var requiredPropositions: [Proposition]
    public var missing: [PropositionID]
    public var scope: Scope
    public var justification: String?

    public init(
        requiredPropositions: [Proposition],
        missing: [PropositionID] = [],
        scope: Scope,
        justification: String? = nil
    ) {
        self.requiredPropositions = requiredPropositions
        self.missing = missing
        self.scope = scope
        self.justification = justification
    }
}

