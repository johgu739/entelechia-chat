import Foundation
import Combine

public final class ContextSelectionState: ObservableObject {
    @Published public var modelChoice: ModelChoice
    @Published public var scopeChoice: ContextScopeChoice
    
    public init(modelChoice: ModelChoice = .codex, scopeChoice: ContextScopeChoice = .selection) {
        self.modelChoice = modelChoice
        self.scopeChoice = scopeChoice
    }
    
    public func setModelChoice(_ choice: ModelChoice) {
        modelChoice = choice
    }
    
    public func setScopeChoice(_ choice: ContextScopeChoice) {
        scopeChoice = choice
    }
}

