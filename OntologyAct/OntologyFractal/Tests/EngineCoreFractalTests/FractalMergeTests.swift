import XCTest
@testable import OntologyFractal
import OntologyCore
import OntologyIntelligence
import OntologyState

final class FractalMergeTests: XCTestCase {

    func testUnionAndContradictionEscalation() {
        let scopeA = FractalScope(
            id: "a",
            includedPropositions: [],
            includedInvariants: [],
            includedRelations: []
        )
        let scopeB = FractalScope(
            id: "b",
            includedPropositions: [],
            includedInvariants: [],
            includedRelations: []
        )

        let inv = Invariant(id: InvariantID("i1"), kind: .state, scope: Scope("x"), statement: "s", severity: .must)
        let dir1: [IntelligenceDirective] = [.strengthenInvariant(inv)]
        let dir2: [IntelligenceDirective] = [.weakenInvariant(inv)]

        let planA = EngineStateRefinementPlan(actions: dir1, notes: ["a"])
        let planB = EngineStateRefinementPlan(actions: dir2, notes: ["b"])

        let merged = DefaultFractalMerger().merge(plans: [scopeA: planA, scopeB: planB])
        XCTAssertTrue(merged.actions.contains { if case .escalateToHuman = $0 { return true } else { return false } })
        XCTAssertEqual(merged.notes.count, 2)
    }
}

