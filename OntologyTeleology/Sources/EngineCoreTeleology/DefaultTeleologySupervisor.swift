import OntologyCore
import OntologyAct
import OntologyState

public struct DefaultTeleologySupervisor: TeleologySupervising {
    public init() {}

    public func evaluatePreconditions(for state: EngineState) -> TeleologyReport {
        var notes: [String] = []
        let conflicts: [Invariant] = []

        let propIDs = Set(state.propositions.propositions.map { $0.id })
        for rel in state.relationGraph.relations {
            if !propIDs.contains(rel.from) || !propIDs.contains(rel.to) {
                notes.append("relation references missing proposition")
                // Structural violation treated as invariant-like for now.
            }
        }

        // Teleology-class invariants: filter by kind == .teleology
        let teleologyInvs = state.invariants.invariants.filter { $0.kind == .teleology }
        let violated: [Invariant] = conflicts + teleologyInvs /* placeholder: no evaluation logic yet */

        if !notes.isEmpty {
            return TeleologyReport(
                status: .violated,
                missingPrerequisites: [],
                unresolvedProjections: [],
                violatedInvariants: teleologyInvs,
                notes: notes
            )
        }

        // Placeholder for projections/prereqs; using state engine placeholders (none).
        let unresolved: [Projection] = []
        let missing: [Prerequisite] = []

        if violated.isEmpty && unresolved.isEmpty && missing.isEmpty {
            return TeleologyReport(status: .satisfied, notes: [])
        } else if !violated.isEmpty {
            return TeleologyReport(status: .violated, violatedInvariants: violated, notes: [])
        } else {
            return TeleologyReport(
                status: .deficient,
                missingPrerequisites: missing,
                unresolvedProjections: unresolved,
                violatedInvariants: violated,
                notes: []
            )
        }
    }

    public func evaluatePostconditions(for state: EngineState) -> TeleologyReport {
        // For STATE v1, mirror preconditions for now.
        return evaluatePreconditions(for: state)
    }

    public func mustBlockSeal(report: TeleologyReport) -> Bool {
        report.status == .violated
    }

    public func mustForceRevision(report: TeleologyReport) -> Bool {
        report.status == .violated
    }
}

