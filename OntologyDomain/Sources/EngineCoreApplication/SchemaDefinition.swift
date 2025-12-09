import OntologyCore
import OntologyState
import OntologyIntegration
import OntologyIntelligence

public func generateBaseInvariants(from schema: DomainSchemaProtocol) -> [Invariant] {
    schema.requiredInvariants
}

public func generateCanonicalRelations(from schema: DomainSchemaProtocol) -> [Relation] {
    // Placeholder: schema-provided projection rules can imply relations; return empty for determinism.
    return []
}

public func inferDomainPrerequisites(_ schema: DomainSchemaProtocol, state: EngineState) -> [Prerequisite] {
    schema.canonicalRetrodictionRules(for: state.propositions)
}

public func inferDomainProjections(_ schema: DomainSchemaProtocol, state: EngineState) -> [Projection] {
    schema.canonicalProjectionRules(for: state.propositions)
}

public func localScope(for proposition: Proposition, schema: DomainSchemaProtocol) -> DomainScope {
    schema.localScope(for: proposition)
}

public func mergeDomainReports(_ reports: [IntegratedEngineReport]) -> IntegratedEngineReport {
    // Deterministic merge: pick worst coherence status, union actions.
    let coherence = reports.map { $0.coherence }
    let plan = reports.map { $0.plan }

    let worstStatus = coherence.map { $0.status }.max(by: statusRank) ?? .coherent
    let mergedConflicts = coherence.flatMap { $0.conflicts }
    let mergedMissing = coherence.flatMap { $0.missing }
    let mergedPending = coherence.flatMap { $0.pending }
    let mergedSat = coherence.flatMap { $0.satisfiedInvariants }
    let mergedViol = coherence.flatMap { $0.violatedInvariants }

    let mergedCoherence = CoherenceReport(
        status: worstStatus,
        conflicts: mergedConflicts,
        missing: mergedMissing,
        pending: mergedPending,
        satisfiedInvariants: mergedSat,
        violatedInvariants: mergedViol,
        scope: coherence.first?.scope ?? Scope("global")
    )

    let mergedActions = plan.flatMap { $0.actions }
    let mergedNotes = plan.flatMap { $0.notes }
    let mergedPlan = EngineStateRefinementPlan(actions: mergedActions, notes: mergedNotes)
    return IntegratedEngineReport(coherence: mergedCoherence, plan: mergedPlan)
}

private func statusRank(_ lhs: CoherenceStatus, _ rhs: CoherenceStatus) -> Bool {
    rank(lhs) < rank(rhs)
}
private func rank(_ s: CoherenceStatus) -> Int {
    switch s {
    case .coherent: return 0
    case .incomplete: return 1
    case .incoherent: return 2
    case .teleologyDeficient: return 1
    }
}

