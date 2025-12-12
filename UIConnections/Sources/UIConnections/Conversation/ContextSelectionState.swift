import Foundation
import Combine
import UIContracts

public final class ContextSelectionState: ObservableObject {
    @Published public var modelChoice: UIContracts.ModelChoice
    @Published public var scopeChoice: UIContracts.ContextScopeChoice
    
    public init(modelChoice: UIContracts.ModelChoice = .codex, scopeChoice: UIContracts.ContextScopeChoice = .selection) {
        self.modelChoice = modelChoice
        self.scopeChoice = scopeChoice
    }
    
    public func setModelChoice(_ choice: UIContracts.ModelChoice) {
        modelChoice = choice
    }
    
    public func setScopeChoice(_ choice: UIContracts.ContextScopeChoice) {
        scopeChoice = choice
    }
}

