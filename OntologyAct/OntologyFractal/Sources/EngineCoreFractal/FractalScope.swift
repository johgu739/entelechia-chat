import OntologyCore

public struct FractalScope: Hashable, Sendable {
    public let id: String
    public let includedPropositions: Set<PropositionID>
    public let includedInvariants: Set<InvariantID>
    public let includedRelations: Set<PropositionPair>

    public init(
        id: String,
        includedPropositions: Set<PropositionID>,
        includedInvariants: Set<InvariantID>,
        includedRelations: Set<PropositionPair>
    ) {
        self.id = id
        self.includedPropositions = includedPropositions
        self.includedInvariants = includedInvariants
        self.includedRelations = includedRelations
    }
}

public struct PropositionPair: Hashable, Sendable {
    public let from: PropositionID
    public let to: PropositionID
    public init(from: PropositionID, to: PropositionID) {
        self.from = from
        self.to = to
    }
}

