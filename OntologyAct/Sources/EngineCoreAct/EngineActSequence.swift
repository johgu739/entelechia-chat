import OntologyCore

public enum EngineActStep: Sendable {
    case receive
    case normalize
    case relate
    case project
    case retrodict
    case check
    case reconcile
    case seal
    case unseal
}

public struct EngineActSequence: Sendable {
    public let steps: [EngineActStep]

    public init(steps: [EngineActStep]) {
        self.steps = steps
    }

    public static let canonical: EngineActSequence = EngineActSequence(steps: [
        .receive, .normalize, .relate, .project, .retrodict, .check, .reconcile, .seal
    ])
}

