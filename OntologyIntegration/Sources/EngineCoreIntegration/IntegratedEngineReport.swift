import OntologyIntelligence
import OntologyCore

public struct IntegratedEngineReport: Sendable {
    public let coherence: CoherenceReport
    public let plan: EngineStateRefinementPlan

    public init(coherence: CoherenceReport, plan: EngineStateRefinementPlan) {
        self.coherence = coherence
        self.plan = plan
    }
}

