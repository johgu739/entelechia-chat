import OntologyCore
import OntologyState
import OntologyIntelligence
import OntologyTeleology

public struct DefaultLocalEngineRunner: LocalEngineRunning {
    public init() {}

    public func runLocal(
        on scope: FractalScope,
        using intelligent: EngineCoreIntelligentEngine
    ) -> EngineStateRefinementPlan {
        // Restrict the state to the scoped propositions/relations/invariants.
        let allState = intelligent.teleological.inner.state
        let props = allState.propositions.propositions.filter { scope.includedPropositions.contains($0.id) }
        let invs = allState.invariants.invariants.filter { scope.includedInvariants.contains($0.id) }
        let rels = allState.relationGraph.relations.filter { scope.includedRelations.contains(PropositionPair(from: $0.from, to: $0.to)) }

        let localState = EngineState(
            propositions: PropositionSet(propositions: props, scope: allState.propositions.scope),
            invariants: InvariantSet(invariants: invs, scope: allState.invariants.scope),
            relationGraph: RelationGraph(propositions: props, relations: rels, scope: allState.relationGraph.scope),
            sealedSlices: [:],
            nextSliceCounter: 0
        )

        let localIntelligent = EngineCoreIntelligentEngine(
            initial: localState,
            supervisor: intelligent.intelligence,
            teleology: intelligent.teleological.supervisor
        )
        return localIntelligent.evaluateAndAdvise()
    }
}

