import OntologyCore

public protocol EngineOrchestrating: Sendable {
    var sequence: EngineActSequence { get }
}

