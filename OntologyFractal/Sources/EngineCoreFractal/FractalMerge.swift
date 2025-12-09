import OntologyIntelligence

public protocol FractalMerging: Sendable {
    func merge(
        plans: [FractalScope: EngineStateRefinementPlan]
    ) -> EngineStateRefinementPlan
}

