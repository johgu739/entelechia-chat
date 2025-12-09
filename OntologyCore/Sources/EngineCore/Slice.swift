public struct SliceID: Hashable, Sendable {
    public var rawValue: String
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct SliceMetadata: Hashable, Sendable {
    public var reason: String?
    public var sealedAtLogical: String?
    public var scope: Scope

    public init(reason: String? = nil, sealedAtLogical: String? = nil, scope: Scope) {
        self.reason = reason
        self.sealedAtLogical = sealedAtLogical
        self.scope = scope
    }
}

public struct Slice: Hashable, Sendable {
    public var id: SliceID
    public var version: Int
    public var propositionSet: PropositionSet
    public var relationGraph: RelationGraph
    public var invariantSet: InvariantSet
    public var metadata: SliceMetadata
    public var parent: SliceID?

    public init(
        id: SliceID,
        version: Int,
        propositionSet: PropositionSet,
        relationGraph: RelationGraph,
        invariantSet: InvariantSet,
        metadata: SliceMetadata,
        parent: SliceID? = nil
    ) {
        self.id = id
        self.version = version
        self.propositionSet = propositionSet
        self.relationGraph = relationGraph
        self.invariantSet = invariantSet
        self.metadata = metadata
        self.parent = parent
    }
}

