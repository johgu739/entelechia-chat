import XCTest
@testable import OntologyFractal
import OntologyCore
import OntologyState
import OntologyIntelligence
import OntologyTeleology

final class LocalEngineTests: XCTestCase {

    func testLocalFullScopeMatchesGlobal() {
        let scope = Scope("s")
        let state = EngineState.empty
        let intelligent = EngineCoreIntelligentEngine(
            initial: state,
            supervisor: DefaultIntelligenceSupervisor(),
            teleology: DefaultTeleologySupervisor()
        )
        let fullScope = FractalScope(
            id: "s",
            includedPropositions: [],
            includedInvariants: [],
            includedRelations: []
        )
        let plan = DefaultLocalEngineRunner().runLocal(on: fullScope, using: intelligent)
        let globalPlan = intelligent.evaluateAndAdvise()
        XCTAssertEqual(plan.actions.count, globalPlan.actions.count)
    }
}

