import XCTest
@testable import OntologyFractal
import OntologyCore
import OntologyState

final class FractalDecompositionTests: XCTestCase {

    func testPartitionsByScopeAndClosesRelations() {
        let scopeA = Scope("a")
        let scopeB = Scope("b")
        let p1 = Proposition(id: PropositionID("p1"), kind: .fact, content: "A", scope: scopeA, provenance: nil, contextTags: [], validity: nil)
        let p2 = Proposition(id: PropositionID("p2"), kind: .fact, content: "B", scope: scopeA, provenance: nil, contextTags: [], validity: nil)
        let p3 = Proposition(id: PropositionID("p3"), kind: .fact, content: "C", scope: scopeB, provenance: nil, contextTags: [], validity: nil)
        let rel = Relation(from: p1.id, to: p2.id, kind: .causal, scope: scopeA, strength: nil, justification: nil, provenance: nil)

        let state = EngineState(
            propositions: PropositionSet(propositions: [p1, p2, p3], scope: scopeA),
            invariants: InvariantSet(invariants: [], scope: scopeA),
            relationGraph: RelationGraph(propositions: [p1, p2, p3], relations: [rel], scope: scopeA),
            sealedSlices: [:],
            nextSliceCounter: 0
        )

        let scopes = DefaultFractalDecomposer().decompose(state: state)
        XCTAssertEqual(scopes.count, 2)
        let a = scopes.first { $0.id == "a" }!
        XCTAssertTrue(a.includedPropositions.contains(p1.id))
        XCTAssertTrue(a.includedRelations.contains(PropositionPair(from: p1.id, to: p2.id)))
    }
}

