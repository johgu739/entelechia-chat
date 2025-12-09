import OntologyCore
import OntologyState
import OntologyTeleology

public struct DefaultIntelligenceSupervisor: IntelligenceSupervising {
    public init() {}

    public func analyze(
        state: EngineState,
        teleology: TeleologyReport
    ) -> [IntelligenceDirective] {
        var directives: [IntelligenceDirective] = []

        switch teleology.status {
        case .violated:
            directives.append(.demandRevision(reason: "teleology violated"))
            for inv in teleology.violatedInvariants {
                directives.append(.strengthenInvariant(inv))
            }
        case .deficient:
            for prereq in teleology.missingPrerequisites {
                directives.append(.requestPrerequisite(prereq))
                if !prereq.missing.isEmpty {
                    let missingList = prereq.missing.map { $0.rawValue }.joined(separator: ",")
                    directives.append(.escalateToHuman(reason: "missing propositions: \(missingList)"))
                }
            }
            for proj in teleology.unresolvedProjections {
                if proj.derivedPropositions.count >= 2 {
                    let from = proj.derivedPropositions[0].id
                    let to = proj.derivedPropositions[1].id
                    let rel = Relation(
                        from: from,
                        to: to,
                        kind: .support,
                        scope: proj.scope,
                        strength: nil,
                        justification: proj.justification,
                        provenance: nil
                    )
                    directives.append(.proposeRelation(rel))
                } else {
                    directives.append(.escalateToHuman(reason: "insufficient projection detail"))
                }
            }
        case .satisfied:
            break
        }

        return directives
    }

    public func refine(
        directives: [IntelligenceDirective],
        state: EngineState
    ) -> EngineStateRefinementPlan {
        let notes = directives.map { directiveDescription($0) }
        return EngineStateRefinementPlan(actions: directives, notes: notes)
    }

    private func directiveDescription(_ d: IntelligenceDirective) -> String {
        switch d {
        case .requestPrerequisite(let prereq):
            let missingList = prereq.missing.map { $0.rawValue }.joined(separator: ",")
            return "requestPrerequisite missing: \(missingList)"
        case .strengthenInvariant(let inv):
            return "strengthenInvariant \(inv.id.rawValue)"
        case .weakenInvariant(let inv):
            return "weakenInvariant \(inv.id.rawValue)"
        case .proposeRelation(let rel):
            return "proposeRelation \(rel.from.rawValue)->\(rel.to.rawValue)"
        case .proposeRetraction(let pid):
            return "proposeRetraction \(pid.rawValue)"
        case .proposeMerge(let a, let b):
            return "proposeMerge \(a.rawValue)+\(b.rawValue)"
        case .demandRevision(let reason):
            return "demandRevision \(reason)"
        case .escalateToHuman(let reason):
            return "escalateToHuman \(reason)"
        }
    }
}

