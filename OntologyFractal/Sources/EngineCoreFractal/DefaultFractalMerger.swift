import OntologyIntelligence

public struct DefaultFractalMerger: FractalMerging {
    public init() {}

    public func merge(
        plans: [FractalScope: EngineStateRefinementPlan]
    ) -> EngineStateRefinementPlan {
        // Stable scope order by id
        let scopes = plans.keys.sorted { $0.id < $1.id }
        var mergedActions: [IntelligenceDirective] = []
        var mergedNotes: [String] = []

        for scope in scopes {
            guard let plan = plans[scope] else { continue }
            mergedNotes.append(contentsOf: plan.notes.map { "[scope \(scope.id)] \($0)" })
            mergedActions.append(contentsOf: plan.actions)
        }

        // Collapse identical directives (by textual description)
        var seen: Set<String> = []
        mergedActions = mergedActions.filter { dir in
            let key = describe(dir)
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        // Detect contradictory directives: e.g., strengthen and weaken same invariant, or proposeRelation vs proposeRetraction same proposition.
        var escalateReasons: [String] = []
        for action in mergedActions {
            switch action {
            case .strengthenInvariant(let inv):
                if mergedActions.contains(where: {
                    if case .weakenInvariant(let other) = $0 { return other.id == inv.id }
                    return false
                }) {
                    escalateReasons.append("contradict invariant \(inv.id.rawValue)")
                }
            case .proposeRetraction(let pid):
                if mergedActions.contains(where: {
                    if case .requestPrerequisite(let prereq) = $0 { return prereq.missing.contains(pid) }
                    return false
                }) {
                    escalateReasons.append("contradict retraction/prereq \(pid.rawValue)")
                }
            default:
                break
            }
        }

        if !escalateReasons.isEmpty {
            mergedActions.append(.escalateToHuman(reason: escalateReasons.joined(separator: "; ")))
        }

        return EngineStateRefinementPlan(actions: mergedActions, notes: mergedNotes)
    }

    private func describe(_ d: IntelligenceDirective) -> String {
        switch d {
        case .requestPrerequisite(let prereq):
            return "requestPrerequisite:\(prereq.missing.map { $0.rawValue }.joined(separator: ","))"
        case .strengthenInvariant(let inv):
            return "strengthenInvariant:\(inv.id.rawValue)"
        case .weakenInvariant(let inv):
            return "weakenInvariant:\(inv.id.rawValue)"
        case .proposeRelation(let rel):
            return "proposeRelation:\(rel.from.rawValue)->\(rel.to.rawValue)"
        case .proposeRetraction(let pid):
            return "proposeRetraction:\(pid.rawValue)"
        case .proposeMerge(let a, let b):
            return "proposeMerge:\(a.rawValue)+\(b.rawValue)"
        case .demandRevision(let reason):
            return "demandRevision:\(reason)"
        case .escalateToHuman(let reason):
            return "escalate:\(reason)"
        }
    }
}

