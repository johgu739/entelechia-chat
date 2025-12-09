import XCTest
@testable import OntologyTeleology
import OntologyCore
import OntologyState

final class EngineCoreTeleologicalEngineTests: XCTestCase {

    func testSealBlockedWhenPreconditionsViolated() {
        let scope = Scope("s")
        let rel = Relation(from: PropositionID("a"), to: PropositionID("b"), kind: .causal, scope: scope, strength: nil, justification: nil, provenance: nil)
        let state = EngineState(
            propositions: PropositionSet(propositions: [], scope: scope),
            invariants: InvariantSet(invariants: [], scope: scope),
            relationGraph: RelationGraph(propositions: [], relations: [rel], scope: scope),
            sealedSlices: [:],
            nextSliceCounter: 0
        )
        var engine = EngineCoreTeleologicalEngine(initial: state)
        let eff = engine.sealSlice(label: "bad")
        XCTAssertEqual(eff.kind, .rejected)
    }

    func testSealAllowedWhenNoViolation() {
        var engine = EngineCoreTeleologicalEngine()
        let eff = engine.sealSlice(label: "ok")
        XCTAssertEqual(eff.kind, .sealed)
    }

    func testReceiveInvariantTriggersNoForceWhenClean() {
        var engine = EngineCoreTeleologicalEngine()
        let inv = Invariant(id: InvariantID("i1"), kind: .state, scope: Scope("s"), statement: "S", severity: .must)
        let eff = engine.receiveInvariant(inv)
        XCTAssertEqual(eff.kind, .accepted)
    }

    func testSummarizeIncludesTeleologyNoteOnViolation() {
        let scope = Scope("s")
        let rel = Relation(from: PropositionID("a"), to: PropositionID("b"), kind: .causal, scope: scope, strength: nil, justification: nil, provenance: nil)
        let state = EngineState(
            propositions: PropositionSet(propositions: [], scope: scope),
            invariants: InvariantSet(invariants: [], scope: scope),
            relationGraph: RelationGraph(propositions: [], relations: [rel], scope: scope),
            sealedSlices: [:],
            nextSliceCounter: 0
        )
        let engine = EngineCoreTeleologicalEngine(initial: state)
        let view = engine.summarizeView(scope: scope, lens: Optional<String>.none)
        XCTAssertTrue(view.summary?.contains("teleology") == true)
    }

    func testMustForceRevisionOnViolation() {
        let scope = Scope("s")
        let rel = Relation(from: PropositionID("a"), to: PropositionID("b"), kind: .causal, scope: scope, strength: nil, justification: nil, provenance: nil)
        let state = EngineState(
            propositions: PropositionSet(propositions: [], scope: scope),
            invariants: InvariantSet(invariants: [], scope: scope),
            relationGraph: RelationGraph(propositions: [], relations: [rel], scope: scope),
            sealedSlices: [:],
            nextSliceCounter: 0
        )
        let supervisor = DefaultTeleologySupervisor()
        let report = supervisor.evaluatePreconditions(for: state)
        XCTAssertTrue(supervisor.mustForceRevision(report: report))
    }
}

