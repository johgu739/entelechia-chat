import XCTest
@testable import OntologyFractal
import OntologyCore
import OntologyState
import OntologyIntelligence
import OntologyTeleology

final class FractalEngineIntegrationTests: XCTestCase {

    func testEvaluateFractallyMergesScopes() {
        let scopeA = Scope("a")
        let scopeB = Scope("b")
        let pA = Proposition(id: PropositionID("pa"), kind: .fact, content: "A", scope: scopeA, provenance: nil, contextTags: [], validity: nil)
        let pB = Proposition(id: PropositionID("pb"), kind: .fact, content: "B", scope: scopeB, provenance: nil, contextTags: [], validity: nil)

        let missing = Prerequisite(requiredPropositions: [], missing: [pA.id], scope: scopeA, justification: nil)
        let inv = Invariant(id: InvariantID("i1"), kind: .teleology, scope: scopeB, statement: "t", severity: .must)
        let teleReportA = TeleologyReport(status: .deficient, missingPrerequisites: [missing], unresolvedProjections: [], violatedInvariants: [], notes: [])
        struct ScopedTeleology: TeleologySupervising {
            let report: TeleologyReport
            func evaluatePreconditions(for state: EngineState) -> TeleologyReport { report }
            func evaluatePostconditions(for state: EngineState) -> TeleologyReport { report }
            func mustBlockSeal(report: TeleologyReport) -> Bool { report.status == .violated }
            func mustForceRevision(report: TeleologyReport) -> Bool { report.status == .violated }
        }

        // Build state with two scopes
        let state = EngineState(
            propositions: PropositionSet(propositions: [pA, pB], scope: scopeA),
            invariants: InvariantSet(invariants: [inv], scope: scopeA),
            relationGraph: RelationGraph(propositions: [pA, pB], relations: [], scope: scopeA),
            sealedSlices: [:],
            nextSliceCounter: 0
        )

        let intelligent = EngineCoreIntelligentEngine(
            initial: state,
            supervisor: DefaultIntelligenceSupervisor(),
            teleology: ScopedTeleology(report: teleReportA)
        )

        let fractal = EngineCoreFractalEngine(intelligent: intelligent)
        let plan = fractal.evaluateFractally()

        XCTAssertTrue(plan.actions.contains { if case .requestPrerequisite = $0 { return true } else { return false } })
        // With only one teleology report provided, we expect deficiency directives but not demandRevision.
        XCTAssertFalse(plan.actions.contains { if case .demandRevision = $0 { return true } else { return false } })
    }
}

