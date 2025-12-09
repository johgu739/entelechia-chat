import OntologyCore
import OntologyState
import OntologyTeleology

public struct EngineCoreIntelligentEngine: Sendable {
    public private(set) var teleological: EngineCoreTeleologicalEngine
    public let intelligence: IntelligenceSupervising

    public init(
        initial: EngineState = .empty,
        supervisor: IntelligenceSupervising = DefaultIntelligenceSupervisor(),
        teleology: TeleologySupervising = DefaultTeleologySupervisor()
    ) {
        self.teleological = EngineCoreTeleologicalEngine(initial: initial, supervisor: teleology)
        self.intelligence = supervisor
    }

    public func evaluateAndAdvise() -> EngineStateRefinementPlan {
        let teleologyReport = teleological.supervisor.evaluatePreconditions(for: teleological.inner.state)
        let directives = intelligence.analyze(state: teleological.inner.state, teleology: teleologyReport)
        let plan = intelligence.refine(directives: directives, state: teleological.inner.state)
        return plan
    }
}

