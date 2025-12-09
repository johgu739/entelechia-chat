@preconcurrency import OntologyCore

public struct EngineCoreBinder: @unchecked Sendable {
    public let receiver: PropositionReceiving & InvariantReceiving
    public let projector: ForwardProjecting
    public let retrodictor: BackwardRetrodicting
    public let checker: CoherenceChecking
    public let reconciler: ConflictReconciling
    public let sealer: SliceSealing
    public let unsealer: SliceUnsealing
    public let summarizer: ViewSummarizing

    public init(
        receiver: PropositionReceiving & InvariantReceiving,
        projector: ForwardProjecting,
        retrodictor: BackwardRetrodicting,
        checker: CoherenceChecking,
        reconciler: ConflictReconciling,
        sealer: SliceSealing,
        unsealer: SliceUnsealing,
        summarizer: ViewSummarizing
    ) {
        self.receiver = receiver
        self.projector = projector
        self.retrodictor = retrodictor
        self.checker = checker
        self.reconciler = reconciler
        self.sealer = sealer
        self.unsealer = unsealer
        self.summarizer = summarizer
    }
}

