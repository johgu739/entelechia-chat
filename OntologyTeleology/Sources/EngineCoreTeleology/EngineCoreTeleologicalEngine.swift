import OntologyCore
import OntologyAct
import OntologyState

public struct EngineCoreTeleologicalEngine: Sendable {
    public private(set) var inner: EngineCoreStateEngine
    public let supervisor: TeleologySupervising

    public init(
        initial: EngineState = .empty,
        supervisor: TeleologySupervising = DefaultTeleologySupervisor()
    ) {
        self.inner = EngineCoreStateEngine(state: initial)
        self.supervisor = supervisor
    }

    // MARK: - Receive Proposition / Invariant
    public mutating func receiveProposition(_ proposition: Proposition) -> Effect {
        let (newState, effect) = inner.receivePropositionUpdatingState(proposition)
        inner = inner.withState(newState)
        let pre = supervisor.evaluatePreconditions(for: inner.state)
        if supervisor.mustForceRevision(report: pre) {
            return Effect(kind: effect.kind, delta: effect.delta, notes: (effect.notes ?? "") + " teleology: revision required")
        }
        return effect
    }

    public mutating func receiveInvariant(_ invariant: Invariant) -> Effect {
        let (newState, effect) = inner.receiveInvariantUpdatingState(invariant)
        inner = inner.withState(newState)
        let pre = supervisor.evaluatePreconditions(for: inner.state)
        if supervisor.mustForceRevision(report: pre) {
            return Effect(kind: effect.kind, delta: effect.delta, notes: (effect.notes ?? "") + " teleology: revision required")
        }
        return effect
    }

    // MARK: - Project / Retrodict (pass through)
    public func projectForward(scope: Scope?) -> [Projection] {
        inner.projectForward(scope: scope)
    }

    public func retrodictPrerequisites(scope: Scope?) -> [Prerequisite] {
        inner.retrodictPrerequisites(scope: scope)
    }

    // MARK: - Coherence
    public func checkCoherence(scope: Scope?) -> CoherenceReport {
        inner.checkCoherence(scope: scope)
    }

    // MARK: - Reconcile
    public mutating func reconcile(_ conflict: Conflict) -> Resolution {
        let (_, resolution) = inner.reconcileConflict(conflict)
        let pre = supervisor.evaluatePreconditions(for: inner.state)
        if supervisor.mustForceRevision(report: pre) {
            return Resolution(
                actions: resolution.actions,
                residualRisk: "teleology violation persists",
                satisfiedInvariants: resolution.satisfiedInvariants,
                scope: resolution.scope,
                notes: "revision required"
            )
        }
        return resolution
    }

    // MARK: - Seal / Unseal
    public mutating func sealSlice(label: String?) -> Effect {
        let pre = supervisor.evaluatePreconditions(for: inner.state)
        if supervisor.mustBlockSeal(report: pre) {
            return Effect(kind: .rejected, delta: nil, notes: "teleology violation blocks seal")
        }
        let (newState, slice) = inner.sealSliceUpdatingState(label: label)
        inner = inner.withState(newState)
        _ = supervisor.evaluatePostconditions(for: inner.state)
        return Effect(kind: .sealed, delta: nil, notes: "sealed \(slice.id.rawValue)")
    }

    public mutating func unsealSlice(_ sliceID: SliceID, reason: String) -> Effect {
        let (newState, effect) = inner.unsealSliceUpdatingState(sliceID, reason: reason)
        inner = inner.withState(newState)
        return effect
    }

    // MARK: - Summaries
    public func summarizeView(scope: Scope?, lens: String?) -> View {
        var view = inner.summarizeView(scope: scope, lens: lens)
        let pre = supervisor.evaluatePreconditions(for: inner.state)
        var notes = pre.notes
        if pre.status == .violated {
            notes.append("teleology violated")
        } else if pre.status == .deficient {
            notes.append("teleology deficient")
        }
        if !notes.isEmpty {
            let augmented = (view.summary ?? "") + " " + notes.joined(separator: ";")
            view = View(slice: view.slice, scope: view.scope, lens: view.lens, summary: augmented)
        }
        return view
    }
}

private extension EngineCoreStateEngine {
    func withState(_ newState: EngineState) -> EngineCoreStateEngine {
        EngineCoreStateEngine(state: newState)
    }
}

