import XCTest
@testable import OntologyAct

final class EngineActSequenceTests: XCTestCase {
    func testCanonicalSequenceIsStable() {
        let canonical = EngineActSequence.canonical.steps
        XCTAssertEqual(canonical, [.receive, .normalize, .relate, .project, .retrodict, .check, .reconcile, .seal])
    }
}

