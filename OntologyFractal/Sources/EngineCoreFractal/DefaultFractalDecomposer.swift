import OntologyCore
import OntologyState

public struct DefaultFractalDecomposer: FractalDecomposing {
    public init() {}

    public func decompose(state: EngineState) -> [FractalScope] {
        // Partition propositions by their scope name.
        var buckets: [String: Set<PropositionID>] = [:]
        for p in state.propositions.propositions {
            buckets[p.scope.name, default: []].insert(p.id)
        }

        var scopes: [FractalScope] = []
        for (scopeName, propIDs) in buckets {
            let invIDs = Set(state.invariants.invariants.filter { $0.scope.name == scopeName }.map { $0.id })
            var relPairs: Set<PropositionPair> = []
            for rel in state.relationGraph.relations where rel.scope.name == scopeName {
                if propIDs.contains(rel.from) || propIDs.contains(rel.to) {
                    relPairs.insert(PropositionPair(from: rel.from, to: rel.to))
                }
            }
            let scope = FractalScope(
                id: scopeName,
                includedPropositions: propIDs,
                includedInvariants: invIDs,
                includedRelations: relPairs
            )
            scopes.append(scope)
        }
        return scopes
    }
}

