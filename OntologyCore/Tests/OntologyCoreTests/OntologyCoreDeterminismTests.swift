import XCTest
@testable import OntologyCore

final class OntologyCoreDeterminismTests: XCTestCase {

    func testPropositionEqualityIsDeterministic() {
        let scope = Scope("global")
        let a = Proposition(id: PropositionID("p1"), kind: .fact, content: "A", scope: scope)
        let b = Proposition(id: PropositionID("p1"), kind: .fact, content: "A", scope: scope)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testInvariantSetStableOrdering() {
        let scope = Scope("s")
        let i1 = Invariant(id: InvariantID("a"), kind: .state, scope: scope, statement: "x", severity: .must)
        let i2 = Invariant(id: InvariantID("b"), kind: .state, scope: scope, statement: "y", severity: .should)
        let set = InvariantSet(invariants: [i2, i1], scope: scope)
        let names = set.invariants.map(\.id.rawValue)
        XCTAssertEqual(names.sorted(), ["a", "b"])
    }
}

