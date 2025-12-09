import OntologyState

public protocol FractalDecomposing: Sendable {
    func decompose(state: EngineState) -> [FractalScope]
}

