import OntologyState
import OntologyIntelligence

public struct EngineCoreFractalEngine: Sendable {
    public var intelligent: EngineCoreIntelligentEngine
    public let decomposer: FractalDecomposing
    public let localRunner: LocalEngineRunning
    public let merger: FractalMerging

    public init(
        intelligent: EngineCoreIntelligentEngine,
        decomposer: FractalDecomposing = DefaultFractalDecomposer(),
        localRunner: LocalEngineRunning = DefaultLocalEngineRunner(),
        merger: FractalMerging = DefaultFractalMerger()
    ) {
        self.intelligent = intelligent
        self.decomposer = decomposer
        self.localRunner = localRunner
        self.merger = merger
    }

    public func evaluateFractally() -> EngineStateRefinementPlan {
        let state = intelligent.teleological.inner.state
        let scopes = decomposer.decompose(state: state)
        var plans: [FractalScope: EngineStateRefinementPlan] = [:]
        for scope in scopes {
            let plan = localRunner.runLocal(on: scope, using: intelligent)
            plans[scope] = plan
        }
        return merger.merge(plans: plans)
    }
}

