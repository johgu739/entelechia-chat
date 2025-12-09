import OntologyCore
import OntologyState

public struct TeleologyReport: Sendable {
    public enum Status: Sendable { case satisfied, deficient, violated }
    public let status: Status
    public let missingPrerequisites: [Prerequisite]
    public let unresolvedProjections: [Projection]
    public let violatedInvariants: [Invariant]
    public let notes: [String]

    public init(
        status: Status,
        missingPrerequisites: [Prerequisite] = [],
        unresolvedProjections: [Projection] = [],
        violatedInvariants: [Invariant] = [],
        notes: [String] = []
    ) {
        self.status = status
        self.missingPrerequisites = missingPrerequisites
        self.unresolvedProjections = unresolvedProjections
        self.violatedInvariants = violatedInvariants
        self.notes = notes
    }
}

public protocol TeleologySupervising: Sendable {
    func evaluatePreconditions(for state: EngineState) -> TeleologyReport
    func evaluatePostconditions(for state: EngineState) -> TeleologyReport
    func mustBlockSeal(report: TeleologyReport) -> Bool
    func mustForceRevision(report: TeleologyReport) -> Bool
}

