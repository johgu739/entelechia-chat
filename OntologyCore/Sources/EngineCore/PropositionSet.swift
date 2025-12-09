public struct PropositionSet: Hashable, Sendable {
    public var propositions: [Proposition]
    public var scope: Scope

    public init(propositions: [Proposition] = [], scope: Scope) {
        self.propositions = propositions
        self.scope = scope
    }
}

