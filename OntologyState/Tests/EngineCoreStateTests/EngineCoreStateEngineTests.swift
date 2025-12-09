import XCTest
@testable import OntologyState
import OntologyCore

final class EngineCoreStateEngineTests: XCTestCase {

    func testReceivePropositionInsertsAndRejectsDuplicate() {
        var engine = EngineCoreStateEngine()
        let p1 = Proposition(id: PropositionID("p1"), kind: .fact, content: "A", scope: Scope("s"), provenance: nil, contextTags: [], validity: nil)

        let (s1, eff1) = engine.receivePropositionUpdatingState(p1)
        XCTAssertEqual(eff1.kind, .accepted)
        XCTAssertEqual(s1.propositions.propositions.count, 1)

        engine = EngineCoreStateEngine(state: s1)
        let (_, eff2) = engine.receivePropositionUpdatingState(p1)
        XCTAssertEqual(eff2.kind, .rejected)
    }

    func testReceiveInvariantInsertsAndRejectsDuplicate() {
        var engine = EngineCoreStateEngine()
        let inv = Invariant(id: InvariantID("i1"), kind: .state, scope: Scope("s"), statement: "S", severity: .must)

        let (s1, e1) = engine.receiveInvariantUpdatingState(inv)
        XCTAssertEqual(e1.kind, .accepted)
        XCTAssertEqual(s1.invariants.invariants.count, 1)

        engine = EngineCoreStateEngine(state: s1)
        let (_, e2) = engine.receiveInvariantUpdatingState(inv)
        XCTAssertEqual(e2.kind, .rejected)
    }

    func testCheckCoherenceEmptyIsIncomplete() {
        let engine = EngineCoreStateEngine()
        let report = engine.checkCoherence(scope: nil)
        XCTAssertEqual(report.status, .incomplete)
        XCTAssertTrue(report.conflicts.isEmpty)
    }

    func testCheckCoherenceFlagsMissingRelationEndpoints() {
        let pScope = Scope("s")
        let rel = Relation(
            from: PropositionID("missingA"),
            to: PropositionID("missingB"),
            kind: .causal,
            scope: pScope,
            strength: nil,
            justification: nil,
            provenance: nil
        )
        let state = EngineState(
            propositions: PropositionSet(propositions: [], scope: pScope),
            invariants: InvariantSet(invariants: [], scope: pScope),
            relationGraph: RelationGraph(propositions: [], relations: [rel], scope: pScope),
            sealedSlices: [:],
            nextSliceCounter: 0
        )
        let engine = EngineCoreStateEngine(state: state)
        let report = engine.checkCoherence(scope: nil)
        XCTAssertEqual(report.status, .incoherent)
        XCTAssertFalse(report.conflicts.isEmpty)
    }

    func testSealSliceAssignsDistinctIds() {
        var engine = EngineCoreStateEngine()
        let (s1, slice1) = engine.sealSliceUpdatingState(label: "first")
        XCTAssertEqual(slice1.id.rawValue, "slice-0")
        XCTAssertEqual(s1.sealedSlices[slice1.id]?.id, slice1.id)

        let (s2, slice2) = EngineCoreStateEngine(state: s1).sealSliceUpdatingState(label: "second")
        XCTAssertEqual(slice2.id.rawValue, "slice-1")
        XCTAssertEqual(s2.sealedSlices.count, 2)
    }

    func testSummarizeViewCountsMatch() {
        let scope = Scope("s")
        let p1 = Proposition(id: PropositionID("p1"), kind: .fact, content: "A", scope: scope, provenance: nil, contextTags: [], validity: nil)
        let p2 = Proposition(id: PropositionID("p2"), kind: .fact, content: "B", scope: scope, provenance: nil, contextTags: [], validity: nil)
        let rel = Relation(from: p1.id, to: p2.id, kind: .causal, scope: scope, strength: nil, justification: nil, provenance: nil)
        var state = EngineState(
            propositions: PropositionSet(propositions: [p1, p2], scope: scope),
            invariants: InvariantSet(invariants: [], scope: scope),
            relationGraph: RelationGraph(propositions: [p1, p2], relations: [rel], scope: scope),
            sealedSlices: [:],
            nextSliceCounter: 0
        )
        state.sealedSlices = [:]
        let engine = EngineCoreStateEngine(state: state)
        let view = engine.summarizeView(scope: scope, lens: nil)
        XCTAssertTrue(view.summary?.contains("props:2") == true)
        XCTAssertTrue(view.summary?.contains("rels:1") == true)
        XCTAssertTrue(view.summary?.contains("invs:0") == true)
    }
}

