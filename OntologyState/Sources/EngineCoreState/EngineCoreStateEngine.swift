import OntologyCore
import OntologyAct

/// Deterministic, in-memory realization of the OntologyCore operations over EngineState.
/// No IO, no threading, no adapters — pure value transformations.
public struct EngineCoreStateEngine: Sendable,
    PropositionReceiving,
    InvariantReceiving,
    ForwardProjecting,
    BackwardRetrodicting,
    CoherenceChecking,
    ConflictReconciling,
    SliceSealing,
    SliceUnsealing,
    ViewSummarizing,
    EngineOrchestrating
{
    public private(set) var state: EngineState
    public let sequence: EngineActSequence = .canonical

    public init(state: EngineState = .empty) {
        self.state = state
    }

    // MARK: - PropositionReceiving
    public func receiveProposition(_ proposition: Proposition) -> Effect {
        if state.propositions.propositions.contains(where: { $0.id == proposition.id }) {
            return Effect(kind: .rejected, delta: Delta(), notes: "duplicate proposition id")
        }
        var newProps = state.propositions.propositions
        newProps.append(proposition)
        let delta = Delta(addedPropositions: [proposition])
        return Effect(kind: .accepted, delta: delta)
    }

    // Helper to return updated state + effect
    public func receivePropositionUpdatingState(_ proposition: Proposition) -> (EngineState, Effect) {
        if state.propositions.propositions.contains(where: { $0.id == proposition.id }) {
            return (state, Effect(kind: .rejected, delta: Delta(), notes: "duplicate proposition id"))
        }
        var newProps = state.propositions.propositions
        newProps.append(proposition)
        var newState = state
        newState.propositions = PropositionSet(propositions: newProps, scope: state.propositions.scope)
        let delta = Delta(addedPropositions: [proposition])
        return (newState, Effect(kind: .accepted, delta: delta))
    }

    // MARK: - InvariantReceiving
    public func receiveInvariant(_ invariant: Invariant) -> Effect {
        if state.invariants.invariants.contains(where: { $0.id == invariant.id }) {
            return Effect(kind: .rejected, delta: Delta(), notes: "duplicate invariant id")
        }
        let delta = Delta(addedInvariants: [invariant])
        return Effect(kind: .accepted, delta: delta)
    }

    public func receiveInvariantUpdatingState(_ invariant: Invariant) -> (EngineState, Effect) {
        if state.invariants.invariants.contains(where: { $0.id == invariant.id }) {
            return (state, Effect(kind: .rejected, delta: Delta(), notes: "duplicate invariant id"))
        }
        var newInvs = state.invariants.invariants
        newInvs.append(invariant)
        var newState = state
        newState.invariants = InvariantSet(invariants: newInvs, scope: state.invariants.scope)
        let delta = Delta(addedInvariants: [invariant])
        return (newState, Effect(kind: .accepted, delta: delta))
    }

    // MARK: - ForwardProjecting
    public func projectForward(scope: Scope?) -> [Projection] {
        return []
    }

    // MARK: - BackwardRetrodicting
    public func retrodictPrerequisites(scope: Scope?) -> [Prerequisite] {
        return []
    }

    // MARK: - CoherenceChecking
    public func checkCoherence(scope: Scope?) -> CoherenceReport {
        let targetScope = scope ?? state.propositions.scope
        var conflicts: [Conflict] = []

        let propIDs = Set(state.propositions.propositions.filter { $0.scope == targetScope }.map { $0.id })
        let rels = state.relationGraph.relations.filter { $0.scope == targetScope }

        for rel in rels {
            if !propIDs.contains(rel.from) || !propIDs.contains(rel.to) {
                let conflict = Conflict(
                    offendingPropositions: [rel.from, rel.to],
                    offendingRelations: [rel],
                    violatedInvariants: [],
                    scope: targetScope,
                    severity: .high,
                    causeChain: ["relation references missing proposition"]
                )
                conflicts.append(conflict)
            }
        }

        if !conflicts.isEmpty {
            return CoherenceReport(
                status: .incoherent,
                conflicts: conflicts,
                missing: [],
                pending: [],
                satisfiedInvariants: [],
                violatedInvariants: [],
                scope: targetScope
            )
        }

        if state.invariants.invariants.isEmpty {
            return CoherenceReport(
                status: .incomplete,
                conflicts: [],
                missing: [],
                pending: [],
                satisfiedInvariants: [],
                violatedInvariants: [],
                scope: targetScope
            )
        }

        return CoherenceReport(
            status: .incomplete,
            conflicts: [],
            missing: [],
            pending: [],
            satisfiedInvariants: [],
            violatedInvariants: [],
            scope: targetScope
        )
    }

    // MARK: - ConflictReconciling
    public func reconcile(_ conflict: Conflict) -> Resolution {
        Resolution(
            actions: [],
            residualRisk: "unresolved at STATE v1",
            satisfiedInvariants: [],
            scope: conflict.scope,
            notes: nil
        )
    }

    public func reconcileConflict(_ conflict: Conflict) -> (EngineState, Resolution) {
        (state, reconcile(conflict))
    }

    // MARK: - SliceSealing
    public func sealSlice(label: String?) -> Slice {
        let id = SliceID("slice-\(state.nextSliceCounter)")
        let metadata = SliceMetadata(reason: label, sealedAtLogical: "\(state.nextSliceCounter)", scope: state.relationGraph.scope)
        let slice = Slice(
            id: id,
            version: state.nextSliceCounter,
            propositionSet: state.propositions,
            relationGraph: state.relationGraph,
            invariantSet: state.invariants,
            metadata: metadata,
            parent: nil
        )
        return slice
    }

    public func sealSliceUpdatingState(label: String?) -> (EngineState, Slice) {
        let id = SliceID("slice-\(state.nextSliceCounter)")
        let metadata = SliceMetadata(reason: label, sealedAtLogical: "\(state.nextSliceCounter)", scope: state.relationGraph.scope)
        let slice = Slice(
            id: id,
            version: state.nextSliceCounter,
            propositionSet: state.propositions,
            relationGraph: state.relationGraph,
            invariantSet: state.invariants,
            metadata: metadata,
            parent: nil
        )
        var newState = state
        newState.sealedSlices[id] = slice
        newState.nextSliceCounter += 1
        return (newState, slice)
    }

    // MARK: - SliceUnsealing
    public func unsealSlice(_ slice: Slice, reason: String) -> Effect {
        // Minimal placeholder: do not modify state; just acknowledge.
        return Effect(kind: .revised, delta: nil, notes: "unseal requested for \(slice.id.rawValue): \(reason)")
    }

    public func unsealSliceUpdatingState(_ sliceID: SliceID, reason: String) -> (EngineState, Effect) {
        guard let slice = state.sealedSlices[sliceID] else {
            return (state, Effect(kind: .rejected, delta: nil, notes: "unknown slice id"))
        }
        return (state, unsealSlice(slice, reason: reason))
    }

    // MARK: - ViewSummarizing
    public func summarizeView(scope: Scope?, lens: String?) -> View {
        let targetScope = scope ?? state.propositions.scope
        let propCount = state.propositions.propositions.filter { $0.scope == targetScope }.count
        let relCount = state.relationGraph.relations.filter { $0.scope == targetScope }.count
        let invCount = state.invariants.invariants.filter { $0.scope == targetScope }.count
        let sliceID = state.sealedSlices.keys.sorted { $0.rawValue < $1.rawValue }.last
        let summary = "props:\(propCount) rels:\(relCount) invs:\(invCount)"
        return View(slice: sliceID, scope: targetScope, lens: lens, summary: summary)
    }
}

