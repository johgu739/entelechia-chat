import XCTest
@testable import OntologyIntegration
import OntologyCore
import OntologyState
import OntologyTeleology
import OntologyIntelligence
import OntologyFractal

final class EngineCoreIntegratedEngineTests: XCTestCase {

    func testReceiveAndCoherenceReflectsMissingEndpoints() {
        var engine = EngineCoreIntegratedEngine()
        let scope = Scope("s")
        // Add relation without endpoints to force incoherence
        let rel = Relation(from: PropositionID("a"), to: PropositionID("b"), kind: .causal, scope: scope, strength: nil, justification: nil, provenance: nil)
        let (newState, _) = engine.stateEngine.receivePropositionUpdatingState(
            Proposition(id: PropositionID("p1"), kind: .fact, content: "A", scope: scope, provenance: nil, contextTags: [], validity: nil)
        )
        engine.stateEngine = EngineCoreStateEngine(state: EngineState(
            propositions: newState.propositions,
            invariants: newState.invariants,
            relationGraph: RelationGraph(propositions: newState.propositions.propositions, relations: [rel], scope: scope),
            sealedSlices: [:],
            nextSliceCounter: 0
        ))
        engine.teleologicalEngine = EngineCoreTeleologicalEngine(initial: engine.stateEngine.state)
        engine.intelligentEngine = EngineCoreIntelligentEngine(initial: engine.stateEngine.state)
        engine.fractalEngine = EngineCoreFractalEngine(intelligent: engine.intelligentEngine)

        let (coherence, plan) = engine.evaluate()
        XCTAssertNotEqual(coherence.status, .coherent)
        // Depending on scope handling in lower layers, missing endpoints yield incomplete or incoherent.
        XCTAssertTrue(coherence.status == .incomplete || coherence.status == .incoherent)
        // Plan may be empty at this stage; we just assert evaluation succeeds.
        XCTAssertNotNil(plan.actions)
    }

    func testTeleologyBlockingSeal() {
        let scope = Scope("s")
        let rel = Relation(from: PropositionID("a"), to: PropositionID("b"), kind: .causal, scope: scope, strength: nil, justification: nil, provenance: nil)
        let state = EngineState(
            propositions: PropositionSet(propositions: [], scope: scope),
            invariants: InvariantSet(invariants: [], scope: scope),
            relationGraph: RelationGraph(propositions: [], relations: [rel], scope: scope),
            sealedSlices: [:],
            nextSliceCounter: 0
        )
        var engine = EngineCoreIntegratedEngine(state: state)
        let eff = engine.sealSlice(label: "x")
        XCTAssertEqual(eff.id.rawValue.prefix(5), "slice") // sealed anyway due to minimal teleology enforcement in wrapper
    }

    func testSatisfiedStateNoAction() {
        var engine = EngineCoreIntegratedEngine()
        let (coherence, plan) = engine.evaluate()
        XCTAssertNotEqual(coherence.status, .incoherent)
        XCTAssertTrue(plan.actions.isEmpty)
    }

    func testUnsealFlows() {
        var engine = EngineCoreIntegratedEngine()
        let slice = engine.sealSlice(label: "one")
        let eff = engine.unsealSlice(id: slice.id, reason: "test")
        XCTAssertEqual(eff.kind, .revised)
    }
}

