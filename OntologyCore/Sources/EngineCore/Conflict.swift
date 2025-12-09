public enum ConflictSeverity: Sendable {
    case low
    case medium
    case high
    case critical
}

public struct Conflict: Hashable, Sendable {
    public var offendingPropositions: [PropositionID]
    public var offendingRelations: [Relation]
    public var violatedInvariants: [InvariantID]
    public var scope: Scope
    public var severity: ConflictSeverity
    public var causeChain: [String]

    public init(
        offendingPropositions: [PropositionID] = [],
        offendingRelations: [Relation] = [],
        violatedInvariants: [InvariantID] = [],
        scope: Scope,
        severity: ConflictSeverity,
        causeChain: [String] = []
    ) {
        self.offendingPropositions = offendingPropositions
        self.offendingRelations = offendingRelations
        self.violatedInvariants = violatedInvariants
        self.scope = scope
        self.severity = severity
        self.causeChain = causeChain
    }
}

