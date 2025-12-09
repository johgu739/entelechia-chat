import OntologyState
import OntologyIntelligence

public protocol LocalEngineRunning: Sendable {
    func runLocal(
        on scope: FractalScope,
        using intelligent: EngineCoreIntelligentEngine
    ) -> EngineStateRefinementPlan
}

