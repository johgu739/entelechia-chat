import OntologyCore
import OntologyState
import OntologyTeleology
import OntologyIntelligence
import OntologyFractal

public struct EngineCoreIntegratedEngine: Sendable {
    public var stateEngine: EngineCoreStateEngine
    public var teleologicalEngine: EngineCoreTeleologicalEngine
    public var intelligentEngine: EngineCoreIntelligentEngine
    public var fractalEngine: EngineCoreFractalEngine

    public init(
        state: EngineState = .empty
    ) {
        self.stateEngine = EngineCoreStateEngine(state: state)
        self.teleologicalEngine = EngineCoreTeleologicalEngine(initial: state)
        self.intelligentEngine = EngineCoreIntelligentEngine(initial: state)
        self.fractalEngine = EngineCoreFractalEngine(intelligent: intelligentEngine)
    }

    // MARK: - Receives
    public mutating func receive(_ proposition: Proposition) -> Effect {
        let (newState, effect) = stateEngine.receivePropositionUpdatingState(proposition)
        stateEngine = EngineCoreStateEngine(state: newState)
        teleologicalEngine = EngineCoreTeleologicalEngine(initial: newState, supervisor: teleologicalEngine.supervisor)
        intelligentEngine = EngineCoreIntelligentEngine(initial: newState, supervisor: intelligentEngine.intelligence, teleology: teleologicalEngine.supervisor)
        fractalEngine = EngineCoreFractalEngine(intelligent: intelligentEngine)
        return effect
    }

    public mutating func receive(_ invariant: Invariant) -> Effect {
        let (newState, effect) = stateEngine.receiveInvariantUpdatingState(invariant)
        stateEngine = EngineCoreStateEngine(state: newState)
        teleologicalEngine = EngineCoreTeleologicalEngine(initial: newState, supervisor: teleologicalEngine.supervisor)
        intelligentEngine = EngineCoreIntelligentEngine(initial: newState, supervisor: intelligentEngine.intelligence, teleology: teleologicalEngine.supervisor)
        fractalEngine = EngineCoreFractalEngine(intelligent: intelligentEngine)
        return effect
    }

    // MARK: - Evaluate
    public func evaluate() -> (CoherenceReport, EngineStateRefinementPlan) {
        let coherence = teleologicalEngine.checkCoherence(scope: nil)
        let plan = fractalEngine.evaluateFractally()
        return (coherence, plan)
    }

    public func evaluateReport() -> IntegratedEngineReport {
        let (coherence, plan) = evaluate()
        return IntegratedEngineReport(coherence: coherence, plan: plan)
    }

    // MARK: - Seal / Unseal
    public mutating func sealSlice(label: String?) -> Slice {
        let (newState, slice) = stateEngine.sealSliceUpdatingState(label: label)
        stateEngine = EngineCoreStateEngine(state: newState)
        teleologicalEngine = EngineCoreTeleologicalEngine(initial: newState, supervisor: teleologicalEngine.supervisor)
        intelligentEngine = EngineCoreIntelligentEngine(initial: newState, supervisor: intelligentEngine.intelligence, teleology: teleologicalEngine.supervisor)
        fractalEngine = EngineCoreFractalEngine(intelligent: intelligentEngine)
        return slice
    }

    public mutating func unsealSlice(id: SliceID, reason: String) -> Effect {
        let (newState, effect) = stateEngine.unsealSliceUpdatingState(id, reason: reason)
        stateEngine = EngineCoreStateEngine(state: newState)
        teleologicalEngine = EngineCoreTeleologicalEngine(initial: newState, supervisor: teleologicalEngine.supervisor)
        intelligentEngine = EngineCoreIntelligentEngine(initial: newState, supervisor: intelligentEngine.intelligence, teleology: teleologicalEngine.supervisor)
        fractalEngine = EngineCoreFractalEngine(intelligent: intelligentEngine)
        return effect
    }

    // MARK: - Summaries
    public func summarize(scope: Scope?) -> View {
        stateEngine.summarizeView(scope: scope, lens: nil)
    }
}

