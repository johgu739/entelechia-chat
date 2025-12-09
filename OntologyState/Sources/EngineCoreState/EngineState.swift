import OntologyCore

public struct EngineState: Sendable {
    public var propositions: PropositionSet
    public var invariants: InvariantSet
    public var relationGraph: RelationGraph
    public var sealedSlices: [SliceID: Slice]
    public var nextSliceCounter: Int

    public static let empty = EngineState(
        propositions: PropositionSet(propositions: [], scope: Scope("global")),
        invariants: InvariantSet(invariants: [], scope: Scope("global")),
        relationGraph: RelationGraph(propositions: [], relations: [], scope: Scope("global")),
        sealedSlices: [:],
        nextSliceCounter: 0
    )

    public init(
        propositions: PropositionSet,
        invariants: InvariantSet,
        relationGraph: RelationGraph,
        sealedSlices: [SliceID: Slice],
        nextSliceCounter: Int
    ) {
        self.propositions = propositions
        self.invariants = invariants
        self.relationGraph = relationGraph
        self.sealedSlices = sealedSlices
        self.nextSliceCounter = nextSliceCounter
    }
}

