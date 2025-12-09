import OntologyCore

public enum IntelligenceDirective: Sendable {
    case requestPrerequisite(Prerequisite)
    case strengthenInvariant(Invariant)
    case weakenInvariant(Invariant)
    case proposeRelation(Relation)
    case proposeRetraction(PropositionID)
    case proposeMerge(SliceID, SliceID)
    case demandRevision(reason: String)
    case escalateToHuman(reason: String)
}

