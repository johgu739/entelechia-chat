public struct RelationGraph: Hashable, Sendable {
    public var propositions: [Proposition]
    public var relations: [Relation]
    public var scope: Scope

    public init(
        propositions: [Proposition] = [],
        relations: [Relation] = [],
        scope: Scope
    ) {
        self.propositions = propositions
        self.relations = relations
        self.scope = scope
    }
}

