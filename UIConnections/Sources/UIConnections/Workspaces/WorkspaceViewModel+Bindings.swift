import Combine

extension WorkspaceViewModel {
    func bindContextSelection() {
        contextSelection.$scopeChoice
            .sink { [weak self] (choice: ContextScopeChoice) in
                guard let self else { return }
                self.activeScope = choice
            }
            .store(in: &cancellables)
        
        contextSelection.$modelChoice
            .sink { [weak self] (choice: ModelChoice) in
                guard let self else { return }
                self.modelChoice = choice
            }
            .store(in: &cancellables)
    }
}

