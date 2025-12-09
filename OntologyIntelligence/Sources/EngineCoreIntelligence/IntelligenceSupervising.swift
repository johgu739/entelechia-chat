import OntologyCore
import OntologyState
import OntologyTeleology

public struct EngineStateRefinementPlan: Sendable {
    public let actions: [IntelligenceDirective]
    public let notes: [String]

    public init(actions: [IntelligenceDirective], notes: [String]) {
        self.actions = actions
        self.notes = notes
    }
}

public protocol IntelligenceSupervising: Sendable {
    func analyze(
        state: EngineState,
        teleology: TeleologyReport
    ) -> [IntelligenceDirective]

    func refine(
        directives: [IntelligenceDirective],
        state: EngineState
    ) -> EngineStateRefinementPlan
}

