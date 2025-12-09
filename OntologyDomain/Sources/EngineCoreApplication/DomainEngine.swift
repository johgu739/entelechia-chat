import OntologyCore
import OntologyIntegration
import OntologyState

public struct DomainEngine<Schema: DomainSchemaProtocol>: Sendable {
    public var schema: Schema
    public var engine: EngineCoreIntegratedEngine

    public init(schema: Schema, initialState: EngineState = .empty) {
        self.schema = schema
        self.engine = EngineCoreIntegratedEngine(state: initialState)
        // Inject required invariants
        for inv in schema.requiredInvariants {
            _ = self.engine.receive(inv)
        }
    }

    public mutating func receive(_ proposition: Proposition) -> Effect {
        guard schema.allowedPropositionKinds.contains(proposition.kind) else {
            return Effect(kind: .rejected, delta: nil, notes: "schema rejected proposition kind")
        }
        let scopeName = proposition.scope.name
        guard schema.domainScopes.contains(where: { $0.name == scopeName }) else {
            return Effect(kind: .rejected, delta: nil, notes: "schema rejected scope")
        }
        return engine.receive(proposition)
    }

    public mutating func receive(_ invariant: Invariant) -> Effect {
        guard schema.allowedRelationKinds.contains(.causal) || schema.allowedRelationKinds.contains(.support) else {
            // Schema does not restrict invariants directly; accept.
            return engine.receive(invariant)
        }
        return engine.receive(invariant)
    }

    public func evaluate() -> IntegratedEngineReport {
        engine.evaluateReport()
    }

    public mutating func sealSlice(label: String?) -> Effect {
        // If schema enforces teleology, block on demandRevision directives
        let report = engine.evaluateReport()
        if schema.enforceTeleologyBeforeSeal {
            let hasDemandRevision = report.plan.actions.contains {
                if case .demandRevision = $0 { return true } else { return false }
            }
            if hasDemandRevision {
                return Effect(kind: .rejected, delta: nil, notes: "schema teleology blocks seal")
            }
        }
        let slice = engine.sealSlice(label: label)
        return Effect(kind: .sealed, delta: nil, notes: "sealed \(slice.id.rawValue)")
    }

    public mutating func unsealSlice(id: SliceID, reason: String) -> Effect {
        engine.unsealSlice(id: id, reason: reason)
    }
}

