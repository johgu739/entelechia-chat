import XCTest
@testable import OntologyIntelligence
import OntologyCore
import OntologyState
import OntologyTeleology

private struct StubTeleologySupervisor: TeleologySupervising {
    let report: TeleologyReport
    func evaluatePreconditions(for state: EngineState) -> TeleologyReport { report }
    func evaluatePostconditions(for state: EngineState) -> TeleologyReport { report }
    func mustBlockSeal(report: TeleologyReport) -> Bool { report.status == .violated }
    func mustForceRevision(report: TeleologyReport) -> Bool { report.status == .violated }
}

final class EngineCoreIntelligentEngineTests: XCTestCase {

    func testViolatedInvariantsYieldDemandRevisionAndStrengthen() {
        let inv = Invariant(id: InvariantID("t1"), kind: .teleology, scope: Scope("s"), statement: "T", severity: .must)
        let report = TeleologyReport(status: .violated, missingPrerequisites: [], unresolvedProjections: [], violatedInvariants: [inv], notes: [])
        let engine = EngineCoreIntelligentEngine(
            supervisor: DefaultIntelligenceSupervisor(),
            teleology: StubTeleologySupervisor(report: report)
        )
        let plan = engine.evaluateAndAdvise()
        XCTAssertTrue(plan.actions.contains { if case .demandRevision = $0 { return true } else { return false } })
        XCTAssertTrue(plan.actions.contains { if case .strengthenInvariant(let i) = $0 { return i.id == inv.id } else { return false } })
    }

    func testMissingPrerequisitesYieldRequest() {
        let missing = Prerequisite(requiredPropositions: [], missing: [PropositionID("m")], scope: Scope("s"), justification: nil)
        let report = TeleologyReport(status: .deficient, missingPrerequisites: [missing], unresolvedProjections: [], violatedInvariants: [], notes: [])
        let engine = EngineCoreIntelligentEngine(
            supervisor: DefaultIntelligenceSupervisor(),
            teleology: StubTeleologySupervisor(report: report)
        )
        let plan = engine.evaluateAndAdvise()
        XCTAssertTrue(plan.actions.contains { if case .requestPrerequisite = $0 { return true } else { return false } })
    }

    func testUnresolvedProjectionsProposeRelation() {
        let scope = Scope("s")
        let p1 = Proposition(id: PropositionID("a"), kind: .fact, content: "A", scope: scope, provenance: nil, contextTags: [], validity: nil)
        let p2 = Proposition(id: PropositionID("b"), kind: .fact, content: "B", scope: scope, provenance: nil, contextTags: [], validity: nil)
        let proj = Projection(derivedPropositions: [p1, p2], requiredInvariants: [], scope: scope, justification: "link a->b")
        let report = TeleologyReport(status: .deficient, missingPrerequisites: [], unresolvedProjections: [proj], violatedInvariants: [], notes: [])
        let engine = EngineCoreIntelligentEngine(
            supervisor: DefaultIntelligenceSupervisor(),
            teleology: StubTeleologySupervisor(report: report)
        )
        let plan = engine.evaluateAndAdvise()
        XCTAssertTrue(plan.actions.contains { if case .proposeRelation(let rel) = $0 { return rel.from == p1.id && rel.to == p2.id } else { return false } })
    }

    func testSatisfiedTeleologyYieldsNoDirectives() {
        let report = TeleologyReport(status: .satisfied, missingPrerequisites: [], unresolvedProjections: [], violatedInvariants: [], notes: [])
        let engine = EngineCoreIntelligentEngine(
            supervisor: DefaultIntelligenceSupervisor(),
            teleology: StubTeleologySupervisor(report: report)
        )
        let plan = engine.evaluateAndAdvise()
        XCTAssertTrue(plan.actions.isEmpty)
    }

    func testMissingReferencesEscalate() {
        let missing = Prerequisite(requiredPropositions: [], missing: [PropositionID("missing")], scope: Scope("s"), justification: nil)
        let report = TeleologyReport(status: .deficient, missingPrerequisites: [missing], unresolvedProjections: [], violatedInvariants: [], notes: [])
        let engine = EngineCoreIntelligentEngine(
            supervisor: DefaultIntelligenceSupervisor(),
            teleology: StubTeleologySupervisor(report: report)
        )
        let plan = engine.evaluateAndAdvise()
        XCTAssertTrue(plan.actions.contains { if case .escalateToHuman = $0 { return true } else { return false } })
    }

    func testRefinementPlanPreservesOrderAndNotes() {
        let directives: [IntelligenceDirective] = [
            .demandRevision(reason: "r1"),
            .proposeRetraction(PropositionID("p1"))
        ]
        let supervisor = DefaultIntelligenceSupervisor()
        let plan = supervisor.refine(directives: directives, state: .empty)
        XCTAssertEqual(plan.actions.count, directives.count)
        XCTAssertEqual(plan.actions.first?.demandRevisionReason, "r1")
        XCTAssertEqual(plan.notes.count, directives.count)
    }
}

private extension IntelligenceDirective {
    var demandRevisionReason: String? {
        if case .demandRevision(let reason) = self { return reason }
        return nil
    }
}

